FROM apache/superset:4.1.1@sha256:1d1fdaaeb19ce9cdba71620ee1cc6117d73813b2f3b422ce5a1bf752c247b7c0

# Install system dependencies required for building Python packages
USER root
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Trino driver and SQLAlchemy dialect
RUN pip install trino sqlalchemy-trino

# Copy the initialization script and dashboard export
COPY init_superset.sh /app/init_superset.sh
COPY dashboard_export.zip /app/dashboard_export.zip
RUN chmod +x /app/init_superset.sh

# Switch back to the superset user
USER superset
