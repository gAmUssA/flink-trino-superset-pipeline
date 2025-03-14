package com.example;

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.Schema;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableDescriptor;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.table.api.DataTypes;
import org.apache.flink.table.api.Expressions;
import org.apache.flink.types.Row;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static org.apache.flink.table.api.Expressions.$;

/**
 * Flink job to process sensor data from Kafka and write to Iceberg using Table API.
 */
public class SensorDataProcessor {
    private static final Logger LOG = LoggerFactory.getLogger(SensorDataProcessor.class);

    public static void main(String[] args) throws Exception {
        // Set up the table environment
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode()
                .build();
        TableEnvironment tableEnv = TableEnvironment.create(settings);

        // Configure Kafka source table
        tableEnv.createTemporaryTable("sensor_source", TableDescriptor.forConnector("kafka")
                .schema(Schema.newBuilder()
                        .column("sensor_id", DataTypes.STRING())
                        .column("sensor_type", DataTypes.STRING())
                        .column("timestamp", DataTypes.TIMESTAMP(3))
                        .column("location", DataTypes.ROW(
                                DataTypes.FIELD("lat", DataTypes.DOUBLE()),
                                DataTypes.FIELD("lon", DataTypes.DOUBLE()),
                                DataTypes.FIELD("facility", DataTypes.STRING())
                        ))
                        .column("battery_level", DataTypes.DOUBLE())
                        .column("reading", DataTypes.DOUBLE())
                        .column("unit", DataTypes.STRING())
                        .watermark("timestamp", "timestamp - INTERVAL '5' SECOND")
                        .build())
                .option("connector", "kafka")
                .option("topic", "sensor-data")
                .option("properties.bootstrap.servers", "kafka:9092")
                .option("properties.group.id", "sensor-data-processor")
                .option("scan.startup.mode", "earliest-offset")
                .option("format", "json")
                .option("json.ignore-parse-errors", "true")
                .option("json.timestamp-format.standard", "ISO-8601")
                .build());

        // Configure Iceberg catalog
        tableEnv.executeSql("CREATE CATALOG iceberg_catalog WITH (" +
                "'type'='iceberg'," +
                "'catalog-impl'='org.apache.iceberg.rest.RESTCatalog'," +
                "'uri'='http://iceberg-rest:8181'," +
                "'warehouse'='s3://warehouse/'," +
                "'io-impl'='org.apache.iceberg.aws.s3.S3FileIO'," +
                "'s3.endpoint'='http://minio:9000'," +
                "'s3.path-style-access'='true'," +
                "'client.region'='us-east-1'," +
                "'s3.access-key-id'='minioadmin'," +
                "'s3.secret-access-key'='minioadmin'" +
                ")");

        // Use the catalog and create database
        tableEnv.executeSql("USE CATALOG iceberg_catalog");
        tableEnv.executeSql("CREATE DATABASE IF NOT EXISTS db");
        tableEnv.executeSql("USE db");

        // Create the sink table
        tableEnv.executeSql("CREATE TABLE IF NOT EXISTS sensor_sink (" +
                "sensor_id STRING," +
                "sensor_type STRING," +
                "event_time TIMESTAMP(3)," +
                "latitude DOUBLE," +
                "longitude DOUBLE," +
                "facility STRING," +
                "battery_level DOUBLE," +
                "reading DOUBLE," +
                "unit STRING," +
                "processing_time TIMESTAMP(3)," +
                "PRIMARY KEY (sensor_id) NOT ENFORCED" +
                ") WITH (" +
                "'format' = 'parquet'," +
                "'write-format' = 'parquet'" +
                ")");

        // Get the source table
        Table sourceTable = tableEnv.from("sensor_source");

        // Transform the data
        Table resultTable = sourceTable.select(
                $("sensor_id"),
                $("sensor_type"),
                $("timestamp").as("event_time"),
                $("location.lat").as("latitude"),
                $("location.lon").as("longitude"),
                $("location.facility").as("facility"),
                $("battery_level"),
                $("reading"),
                $("unit"),
                Expressions.callSql("CURRENT_TIMESTAMP").as("processing_time")
        );

        // Print the result schema for debugging
        LOG.info("Result schema: {}", resultTable.getSchema());

        // Insert the data into the sink table
        resultTable.executeInsert("sensor_sink");

        LOG.info("Sensor Data Processor job submitted");
    }
}
