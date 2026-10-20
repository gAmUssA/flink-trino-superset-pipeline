FROM apache/superset:6.1.0

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
