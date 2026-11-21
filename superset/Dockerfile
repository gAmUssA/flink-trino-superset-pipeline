FROM apache/superset:6.1.0@sha256:16b50bbef6648912a79e3293d418fefa743ce555d36c5af6b85d859119ed7f88

# Superset 5+ images run from a uv-managed venv at /app/.venv without pip;
# install the Trino driver (includes the SQLAlchemy dialect) into it
USER root
RUN uv pip install --python /app/.venv/bin/python --no-cache trino

# Copy the initialization script and dashboard export
COPY init_superset.sh /app/init_superset.sh
COPY dashboard_export.zip /app/dashboard_export.zip
RUN chmod +x /app/init_superset.sh

# Switch back to the superset user
USER superset
