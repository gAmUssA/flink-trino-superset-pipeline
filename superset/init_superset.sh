#!/bin/bash

# Initialize Superset
echo "Initializing Superset..."

# Create admin user
echo "Creating admin user..."
superset fab create-admin \
    --username admin \
    --firstname Superset \
    --lastname Admin \
    --email admin@superset.com \
    --password admin || \
    echo "Admin user might already exist. Continuing..."

# Upgrade the database
echo "Upgrading database..."
superset db upgrade

# Initialize Superset
echo "Initializing Superset..."
superset init

# Set up database connection to Trino
echo "Setting up database connection to Trino..."
superset set-database-uri -d trino -u trino://admin@trino-coordinator:8080/iceberg/warehouse || \
    echo "Database connection might already exist. Continuing..."

echo "Superset initialization complete!"