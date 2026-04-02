#!/bin/bash

echo "Initializing Superset..."

# Upgrade the database
echo "Upgrading database..."
superset db upgrade

# Create admin user
echo "Creating admin user..."
superset fab create-admin \
    --username admin \
    --firstname Superset \
    --lastname Admin \
    --email admin@superset.com \
    --password admin || \
    echo "Admin user might already exist. Continuing..."

# Initialize Superset
echo "Running superset init..."
superset init

# Import dashboard (includes database connection, datasets, charts, and dashboard)
EXPORT_ZIP="/app/dashboard_export.zip"
if [ -f "$EXPORT_ZIP" ]; then
    echo "Importing dashboard from $EXPORT_ZIP..."
    superset import-dashboards -p "$EXPORT_ZIP" -u admin || \
        echo "Dashboard import had issues, but continuing..."
    echo "Dashboard imported successfully!"
else
    # Fallback: set up database connection manually
    echo "No dashboard export found, setting up Trino connection manually..."
    superset set-database-uri \
        -d trino \
        -u "trino://admin@trino-coordinator:8080/iceberg/warehouse" || \
        echo "Database connection might already exist. Continuing..."
fi

echo "Superset initialization complete!"
echo "Access Superset at http://localhost:8088 (admin/admin)"
