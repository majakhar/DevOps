/*
Terraform IaC to deploy the arithmetic Flask app to AWS using ECR + ECS Fargate + ALB

This single-file module will:
 - Create an ECR repository for the container image
 - Create an ECS cluster
 - Create IAM roles required for ECS Task Execution
 - Create an Application Load Balancer (ALB) with a target group and listener
 - Create a Fargate Task Definition and Service wired to the ALB
 - Create security groups for the ALB and ECS tasks

Notes / assumptions:
 - This module does NOT create a VPC. You must supply an existing VPC ID and at least two public subnets (or private subnets with NAT) to attach the service.
 - You must build and push the Docker image to the created ECR repository (or change the image to an external registry) before the ECS service will have a running task.
 - The ECS service will be created with desired_count (default 1). It will pull the image from ECR using the image tag variable.

Usage example:
 terraform init
 terraform plan -var "aws_region=us-east-1" -var "vpc_id=vpc-0123" -var "public_subnets=[\"subnet-1\",\"subnet-2\"]" -var "image_tag=latest"
 terraform apply -var "aws_region=us-east-1" -var "vpc_id=vpc-0123" -var "public_subnets=[\"subnet-1\",\"subnet-2\"]" -var "image_tag=latest"

After apply, build and push your Docker image to the ECR repository printed in the outputs.

*/

terraform {
  required_version = ">= 1.2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

########################################
# Variables
########################################
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where ECS tasks and ALB will be deployed"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs for ALB and ECS tasks (at least 2)"
  type        = list(string)
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 1
}

variable "image_tag" {
  description = "Tag for the container image to deploy (will be combined with ECR repo URI)"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 5000
}

variable "service_name" {
  description = "Name for ECS service and related resources"
  type        = string
  default     = "arithmetic-flask-app"
}

########################################
# ECR Repository
########################################
resource "aws_ecr_repository" "app" {
  name                 = var.service_name
  image_tag_mutability = "MUTABLE"
  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep last 10 images"
          selection = {
            tagStatus = "any"
            countType = "imageCountMoreThan"
            countNumber = 10
          }
          action = { type = "expire" }
        }
      ]
    })
  }
}

########################################
# IAM role/policy for ECS task execution
########################################
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.service_name}-task-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = { Service = "ecs-tasks.amazonaws.com" },
        Effect = "Allow",
        Sid = "",
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

########################################
# ECS Cluster
########################################
resource "aws_ecs_cluster" "this" {
  name = "${var.service_name}-cluster"
}

########################################
# Security groups
########################################
# ALB SG: allow HTTP from anywhere
resource "aws_security_group" "alb" {
  name        = "${var.service_name}-alb-sg"
  description = "Allow HTTP inbound to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS tasks SG: allow traffic from ALB on container_port
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.service_name}-tasks-sg"
  description = "Allow traffic from ALB to ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

########################################
# Load Balancer
########################################
resource "aws_lb" "app" {
  name               = "${var.service_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnets
}

resource "aws_lb_target_group" "app" {
  name     = "${var.service_name}-tg"
  port     = var.container_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

########################################
# Task Definition and Service
########################################
resource "aws_ecs_task_definition" "app" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "${var.service_name}-container",
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}",
      essential = true,
      portMappings = [
        {
          containerPort = var.container_port,
          hostPort      = var.container_port,
          protocol      = "tcp"
        }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/${var.service_name}",
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# Create CloudWatch log group for ECS logs
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.service_name}"
  retention_in_days = 7
}

resource "aws_ecs_service" "app" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.public_subnets
    security_groups = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.service_name}-container"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]
}

########################################
# Outputs
########################################
output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}
