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
 * Flink job to process user activity data from Kafka and write to Iceberg using Table API.
 */
public class UserActivityProcessor {
    private static final Logger LOG = LoggerFactory.getLogger(UserActivityProcessor.class);

    public static void main(String[] args) throws Exception {
        // Set up the table environment
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode()
                .build();
        TableEnvironment tableEnv = TableEnvironment.create(settings);

        // Configure Kafka source table
        tableEnv.createTemporaryTable("user_activity_source", TableDescriptor.forConnector("kafka")
                .schema(Schema.newBuilder()
                        .column("user_id", DataTypes.STRING())
                        .column("event_type", DataTypes.STRING())
                        .column("timestamp", DataTypes.TIMESTAMP(3))
                        .column("session_id", DataTypes.STRING())
                        .column("ip_address", DataTypes.STRING())
                        .column("user_agent", DataTypes.STRING())
                        .column("page_url", DataTypes.STRING())
                        .column("referrer", DataTypes.STRING())
                        .column("time_spent", DataTypes.INT())
                        .column("element_id", DataTypes.STRING())
                        .column("search_query", DataTypes.STRING())
                        .column("results_count", DataTypes.INT())
                        .column("order_id", DataTypes.STRING())
                        .column("product_ids", DataTypes.ARRAY(DataTypes.STRING()))
                        .column("total_amount", DataTypes.DOUBLE())
                        .column("currency", DataTypes.STRING())
                        .watermark("timestamp", "timestamp - INTERVAL '5' SECOND")
                        .build())
                .option("connector", "kafka")
                .option("topic", "user-activity")
                .option("properties.bootstrap.servers", "kafka:9092")
                .option("properties.group.id", "user-activity-processor")
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
        tableEnv.executeSql("CREATE TABLE IF NOT EXISTS user_activity_sink (" +
                "user_id STRING," +
                "event_type STRING," +
                "event_time TIMESTAMP(3)," +
                "session_id STRING," +
                "ip_address STRING," +
                "user_agent STRING," +
                "page_url STRING," +
                "referrer STRING," +
                "time_spent INT," +
                "element_id STRING," +
                "search_query STRING," +
                "results_count INT," +
                "order_id STRING," +
                "product_ids ARRAY<STRING>," +
                "total_amount DOUBLE," +
                "currency STRING," +
                "processing_time TIMESTAMP(3)," +
                "PRIMARY KEY (user_id, session_id) NOT ENFORCED" +
                ") WITH (" +
                "'format' = 'parquet'," +
                "'write-format' = 'parquet'" +
                ")");

        // Get the source table
        Table sourceTable = tableEnv.from("user_activity_source");

        // Transform the data
        Table resultTable = sourceTable.select(
                $("user_id"),
                $("event_type"),
                $("timestamp").as("event_time"),
                $("session_id"),
                $("ip_address"),
                $("user_agent"),
                $("page_url"),
                $("referrer"),
                $("time_spent"),
                $("element_id"),
                $("search_query"),
                $("results_count"),
                $("order_id"),
                $("product_ids"),
                $("total_amount"),
                $("currency"),
                Expressions.callSql("CURRENT_TIMESTAMP").as("processing_time")
        );

        // Print the result schema for debugging
        LOG.info("Result schema: {}", resultTable.getSchema());

        // Insert the data into the sink table
        resultTable.executeInsert("user_activity_sink");

        LOG.info("User Activity Processor job submitted");
    }
}
