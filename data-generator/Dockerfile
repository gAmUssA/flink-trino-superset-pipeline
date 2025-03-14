FROM python:3.9-slim

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
