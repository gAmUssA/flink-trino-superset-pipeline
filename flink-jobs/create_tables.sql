-- Ensure the Iceberg warehouse schema exists in Trino
-- Tables are created by Flink jobs via the Iceberg REST catalog
CREATE SCHEMA IF NOT EXISTS iceberg.warehouse;

-- Create aggregated views for analytics
-- These views query the Iceberg tables created by Flink

CREATE OR REPLACE VIEW iceberg.warehouse.hourly_user_activity AS
SELECT
    date_trunc('hour', event_time) AS hour,
    event_type,
    COUNT(*) AS event_count
FROM
    iceberg.warehouse.user_activity
GROUP BY
    date_trunc('hour', event_time),
    event_type;

CREATE OR REPLACE VIEW iceberg.warehouse.sensor_stats AS
SELECT
    date_trunc('hour', event_time) AS hour,
    sensor_type,
    facility,
    COUNT(*) AS reading_count,
    AVG(reading) AS avg_value,
    MIN(reading) AS min_value,
    MAX(reading) AS max_value
FROM
    iceberg.warehouse.sensor_data
GROUP BY
    date_trunc('hour', event_time),
    sensor_type,
    facility;
