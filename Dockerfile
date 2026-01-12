# Lightweight Python image
FROM python:3.11-slim

# Set working directory
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
