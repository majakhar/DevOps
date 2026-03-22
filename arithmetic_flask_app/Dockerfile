# Use a slim Python image
FROM python:3.14-slim

# Prevent Python from buffering stdout/stderr and avoid writing .pyc files
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Copy requirements and install Python dependencies (run as root during build)
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# Copy application source into the image
COPY . /app/

# Create a non-root user and make /app owned by that user
# Use a minimal user creation so image remains small
RUN useradd --create-home --home-dir /app --shell /bin/sh appuser && \
    chown -R appuser:appuser /app

# Switch to the non-root user
USER appuser

# Expose the port the app listens on
EXPOSE 5000

# Run the app with gunicorn (runs as appuser)
CMD ["gunicorn", "--bind", "0.0.0.0:8083", "--workers", "1", "app:app"]
