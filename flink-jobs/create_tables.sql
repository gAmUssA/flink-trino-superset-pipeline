-- Ensure the Iceberg warehouse schema exists in Trino
-- Tables are created by Flink jobs via the Iceberg REST catalog
CREATE SCHEMA IF NOT EXISTS iceberg.warehouse;

-- ── Analytics Views ──────────────────────────────────────
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

-- ── Iceberg Snapshot Views ───────────────────────────────
-- committed_at must be cast to timestamp(6) with time zone for Trino Iceberg connector

CREATE OR REPLACE VIEW iceberg.warehouse.sensor_data_snapshots AS
SELECT
    snapshot_id,
    parent_id,
    CAST(committed_at AS timestamp(6) with time zone) AS committed_at,
    operation,
    summary
FROM iceberg.warehouse."sensor_data$snapshots";

CREATE OR REPLACE VIEW iceberg.warehouse.user_activity_snapshots AS
SELECT
    snapshot_id,
    parent_id,
    CAST(committed_at AS timestamp(6) with time zone) AS committed_at,
    operation,
    summary
FROM iceberg.warehouse."user_activity$snapshots";

-- Commit log with metrics extracted from the snapshot summary map
CREATE OR REPLACE VIEW iceberg.warehouse.iceberg_commit_log AS
SELECT
    snapshot_id,
    CAST(committed_at AS timestamp(6) with time zone) AS committed_at,
    operation,
    TRY_CAST(summary['added-records'] AS BIGINT) AS added_records,
    TRY_CAST(summary['total-records'] AS BIGINT) AS total_records,
    TRY_CAST(summary['added-data-files'] AS INTEGER) AS added_files
FROM iceberg.warehouse."sensor_data$snapshots";
