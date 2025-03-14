FROM apache/superset:latest@sha256:41d888e2374b4f0f89dd46e06227248c2fdeaf32ae646b1ed109c29782646c4b

# Install system dependencies required for building Python packages
USER root
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Trino driver
RUN pip install trino

# Copy the initialization script
COPY init_superset.sh /app/init_superset.sh
RUN chmod +x /app/init_superset.sh

# Switch back to the superset user
USER superset
