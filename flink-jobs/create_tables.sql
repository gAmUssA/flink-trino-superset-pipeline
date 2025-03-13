-- Create the Iceberg catalog in Trino
CREATE SCHEMA IF NOT EXISTS iceberg.warehouse;

-- Create user_activity table
CREATE TABLE IF NOT EXISTS iceberg.warehouse.user_activity (
    user_id VARCHAR,
    event_type VARCHAR,
    event_time TIMESTAMP(6),
    session_id VARCHAR,
    ip_address VARCHAR,
    user_agent VARCHAR,
    page_url VARCHAR,
    total_amount DOUBLE
)
WITH (
    format = 'PARQUET',
    partitioning = ARRAY['day(event_time)']
);

-- Create sensor_data table
CREATE TABLE IF NOT EXISTS iceberg.warehouse.sensor_data (
    sensor_id VARCHAR,
    sensor_type VARCHAR,
    event_time TIMESTAMP(6),
    latitude DOUBLE,
    longitude DOUBLE,
    facility VARCHAR,
    sensor_value DOUBLE
)
WITH (
    format = 'PARQUET',
    partitioning = ARRAY['day(event_time)', 'sensor_type']
);

-- Create aggregated views for analytics
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
    AVG(sensor_value) AS avg_value,
    MIN(sensor_value) AS min_value,
    MAX(sensor_value) AS max_value
FROM
    iceberg.warehouse.sensor_data
GROUP BY
    date_trunc('hour', event_time),
    sensor_type,
    facility;
