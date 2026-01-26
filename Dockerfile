# Multi-stage Dockerfile for Simple REST Service
#
# This Dockerfile creates a minimal production container:
# - Base: python:3.11-slim (~125MB)
# - Dependencies: Flask and minimal requirements
# - Port: 80 (configurable via PORT env var)
#
# Build: docker build -t devops-project:latest .
# Run: docker run -d -p 80:80 devops-project:latest

# Use official Python slim image for smaller size
FROM python:3.11-slim

# Set working directory inside container
WORKDIR /app

# Copy dependency list and install
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . /app

# Default to port 80 inside the container
ENV PORT=80
EXPOSE 80

# Start the application; main.py reads PORT env var
CMD ["python", "main.py"]
