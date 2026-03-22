# AI Coding Agent Instructions for DevOps Repository

## Project Overview
This is a **DevOps learning repository** designed to consolidate DevOps knowledge and best practices in one organized location. It's not a production application but an educational reference.

## Repository Structure
- `ssl/` - SSL certificate documentation and learning materials
- `.github/workflows/` - GitHub Actions workflow examples and demos
- `README.md` - High-level topic index

## Key Documentation Patterns
- Each topic has its own directory (e.g., `ssl/`)
- Each topic directory contains a `.md` file with comprehensive notes (e.g., `SSL.md`)
- Content is structured as learning documentation, not code

## When Adding New Topics
1. Create a new directory under the root: `/topic-name/`
2. Add a `TOPIC_NAME.md` file with comprehensive documentation
3. Update `README.md` to add the new topic to the DevOps Topics list
4. Keep documentation clear, concise, and practical with examples where applicable

## GitHub Actions Workflow
- Current workflow: `github-actions-demo.yml` in `.github/workflows/`
- This is a demonstration workflow; extend it for CI/CD purposes specific to DevOps tasks
- Workflows trigger on push events

## Writing Style
- Use markdown for all documentation
- Include practical examples and command-line snippets
- Focus on "why" not just "what" to build understanding
- Link between related concepts where applicable
