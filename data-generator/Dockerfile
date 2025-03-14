FROM python:3.9-slim@sha256:d1fd807555208707ec95b284afd10048d0737e84b5f2d6fdcbed2922b9284b56

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
