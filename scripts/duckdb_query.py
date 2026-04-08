#!/usr/bin/env python3
"""
Query Iceberg tables locally with DuckDB — no server required.

Demonstrates Iceberg's engine independence: Flink writes the data,
Trino serves it, and DuckDB can query it directly from S3 storage.

Usage:
    uv pip install duckdb
    python scripts/duckdb_query.py

Requires the pipeline to be running (docker-compose up) so that
SeaweedFS (S3) and the Iceberg REST catalog are accessible.
"""

import duckdb


def main():
    conn = duckdb.connect()

    # Install and load the Iceberg extension
    conn.sql("INSTALL iceberg; LOAD iceberg;")

    # Attach the Iceberg REST catalog (same one Flink and Trino use)
    conn.sql("""
        ATTACH '' AS iceberg (
            TYPE ICEBERG,
            ENDPOINT_URL 'http://localhost:9000',
            URL_STYLE 'path',
            AUTH_TYPE 'S3',
            CATALOG_TYPE 'rest',
            CATALOG_URI 'http://localhost:8181',
            KEY 'minioadmin',
            SECRET 'minioadmin'
        );
    """)

    print("=" * 60)
    print("Iceberg tables via DuckDB (no Trino needed)")
    print("=" * 60)

    # ── Sensor Data ────────────────────────────────────────
    print("\n── Sensor Data: readings by type ──")
    conn.sql("""
        SELECT
            sensor_type,
            COUNT(*) AS readings,
            ROUND(AVG(reading), 2) AS avg_value,
            ROUND(MIN(reading), 2) AS min_value,
            ROUND(MAX(reading), 2) AS max_value
        FROM iceberg.warehouse.sensor_data
        GROUP BY sensor_type
        ORDER BY readings DESC
    """).show()

    print("\n── Sensor Data: readings by facility ──")
    conn.sql("""
        SELECT
            facility,
            COUNT(*) AS readings,
            ROUND(AVG(battery_level), 1) AS avg_battery
        FROM iceberg.warehouse.sensor_data
        GROUP BY facility
        ORDER BY readings DESC
        LIMIT 10
    """).show()

    # ── User Activity ──────────────────────────────────────
    print("\n── User Activity: events by type ──")
    conn.sql("""
        SELECT
            event_type,
            COUNT(*) AS events
        FROM iceberg.warehouse.user_activity
        GROUP BY event_type
        ORDER BY events DESC
    """).show()

    print("\n── User Activity: purchase summary ──")
    conn.sql("""
        SELECT
            COUNT(*) AS purchases,
            ROUND(AVG(total_amount), 2) AS avg_order,
            ROUND(SUM(total_amount), 2) AS total_revenue
        FROM iceberg.warehouse.user_activity
        WHERE event_type = 'purchase'
    """).show()

    # ── Iceberg Metadata ───────────────────────────────────
    print("\n── Iceberg Snapshots (sensor_data) ──")
    conn.sql("""
        SELECT *
        FROM iceberg.warehouse.sensor_data.snapshots
        ORDER BY committed_at DESC
        LIMIT 5
    """).show()

    print("\nDone. Same Parquet files, no Trino — that's Iceberg portability.")


if __name__ == "__main__":
    main()
