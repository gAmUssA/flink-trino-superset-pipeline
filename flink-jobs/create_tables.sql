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

-- ── Time Travel Queries ───────────────────────────────────
-- Iceberg tracks every commit as a snapshot, enabling point-in-time queries.

-- Show all snapshots (commits) for sensor_data
-- Each row = one Flink checkpoint that committed data to Iceberg
CREATE OR REPLACE VIEW iceberg.warehouse.sensor_data_snapshots AS
SELECT
    snapshot_id,
    parent_id,
    committed_at,
    operation,
    summary
FROM iceberg.warehouse."sensor_data$snapshots";

-- Show all snapshots for user_activity
CREATE OR REPLACE VIEW iceberg.warehouse.user_activity_snapshots AS
SELECT
    snapshot_id,
    parent_id,
    committed_at,
    operation,
    summary
FROM iceberg.warehouse."user_activity$snapshots";

-- Example time-travel queries (run these interactively in Trino CLI):
--
--   -- Sensor data as it looked 10 minutes ago
--   SELECT COUNT(*), AVG(reading) FROM iceberg.warehouse.sensor_data
--     FOR TIMESTAMP AS OF (current_timestamp - interval '10' minute);
--
--   -- User activity as of a specific snapshot
--   SELECT * FROM iceberg.warehouse.user_activity
--     FOR VERSION AS OF 1234567890;  -- use snapshot_id from the snapshots view
--
--   -- Compare current vs 10 minutes ago to see new records
--   SELECT
--     (SELECT COUNT(*) FROM iceberg.warehouse.sensor_data) AS current_count,
--     (SELECT COUNT(*) FROM iceberg.warehouse.sensor_data
--       FOR TIMESTAMP AS OF (current_timestamp - interval '10' minute)) AS past_count;

-- ── Schema Evolution ──────────────────────────────────────
-- Iceberg supports adding columns without rewriting data.
-- Old rows return NULL for new columns; new rows fill them in.

-- Add an alert_threshold column to sensor_data
-- (sensors above this threshold could trigger alerts)
ALTER TABLE iceberg.warehouse.sensor_data ADD COLUMN IF NOT EXISTS alert_threshold DOUBLE;

-- Add a device_type column to user_activity
-- (classify mobile vs desktop from user_agent)
ALTER TABLE iceberg.warehouse.user_activity ADD COLUMN IF NOT EXISTS device_type VARCHAR;

-- ── Superset Views for Iceberg Features ───────────────────
-- These views power the "Iceberg Features" section of the Superset dashboard.

-- Commit log with metrics extracted from the snapshot summary map
CREATE OR REPLACE VIEW iceberg.warehouse.iceberg_commit_log AS
SELECT
    snapshot_id,
    committed_at,
    operation,
    TRY_CAST(summary['added-records'] AS BIGINT) AS added_records,
    TRY_CAST(summary['total-records'] AS BIGINT) AS total_records,
    TRY_CAST(summary['added-data-files'] AS INTEGER) AS added_files
FROM iceberg.warehouse."sensor_data$snapshots";

-- Schema evolution view (must come after ALTER TABLE above)
-- Shows sensor data including the new nullable alert_threshold column
CREATE OR REPLACE VIEW iceberg.warehouse.sensor_schema_evolution AS
SELECT
    sensor_id,
    sensor_type,
    event_time,
    reading,
    unit,
    alert_threshold
FROM iceberg.warehouse.sensor_data;
