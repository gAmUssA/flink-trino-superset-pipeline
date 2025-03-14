FROM python:3.13-slim@sha256:f3614d98f38b0525d670f287b0474385952e28eb43016655dd003d0e28cf8652

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY . .

# Set environment variables
# Use 'local' or 'cloud' to switch between configurations
ENV KAFKA_ENV=local

# Run the data generator
CMD ["python", "data_generator.py"]
