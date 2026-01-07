FROM python:3.11-slim

WORKDIR /app

# Install system dependencies and upgrade pip
RUN pip install --no-cache-dir --upgrade pip

# Copy function code and requirements
COPY functions/aggregate-news/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY functions/aggregate-news /app

# Cloud Run expects PORT env var
ENV PORT=8080

# Run Flask application directly
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=8080"]
