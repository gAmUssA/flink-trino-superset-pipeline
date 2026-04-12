-- ── Schema Evolution Demo ─────────────────────────────────
-- Run via: make schema-evolution
-- Iceberg supports adding columns without rewriting data.
-- Old rows return NULL for new columns; new rows fill them in.

ALTER TABLE iceberg.warehouse.sensor_data ADD COLUMN IF NOT EXISTS alert_threshold DOUBLE;
ALTER TABLE iceberg.warehouse.user_activity ADD COLUMN IF NOT EXISTS device_type VARCHAR;

-- View to show the evolved schema (old rows have NULL for new columns)
CREATE OR REPLACE VIEW iceberg.warehouse.sensor_schema_evolution AS
SELECT
    sensor_id,
    sensor_type,
    event_time,
    reading,
    unit,
    alert_threshold
FROM iceberg.warehouse.sensor_data;
