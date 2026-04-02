package com.example;

import org.apache.flink.table.api.DataTypes;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.Schema;
import org.apache.flink.table.api.TableDescriptor;
import org.apache.flink.table.api.TableEnvironment;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Smoke tests for SensorDataProcessor.
 * Verifies that the job class loads, schemas with nested ROW types are valid,
 * and the Kafka connector descriptor builds correctly.
 */
class SensorDataProcessorTest {

    @Test
    void jobClassLoads() {
        assertDoesNotThrow(() -> Class.forName("com.example.SensorDataProcessor"));
    }

    @Test
    void kafkaSourceSchemaWithNestedRowIsValid() {
        Schema schema = Schema.newBuilder()
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
                .watermark("timestamp", "`timestamp` - INTERVAL '5' SECOND")
                .build();

        assertNotNull(schema);
        assertEquals(7, schema.getColumns().size());
    }

    @Test
    void sensorKafkaDescriptorBuilds() {
        TableDescriptor descriptor = TableDescriptor.forConnector("kafka")
                .schema(Schema.newBuilder()
                        .column("sensor_id", DataTypes.STRING())
                        .column("sensor_type", DataTypes.STRING())
                        .column("reading", DataTypes.DOUBLE())
                        .build())
                .option("connector", "kafka")
                .option("topic", "sensor-data")
                .option("properties.bootstrap.servers", "localhost:9092")
                .option("format", "json")
                .option("json.ignore-parse-errors", "true")
                .option("json.timestamp-format.standard", "ISO-8601")
                .build();

        assertNotNull(descriptor);
    }

    @Test
    void icebergSinkTableSqlIsValid() {
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode()
                .build();
        TableEnvironment tableEnv = TableEnvironment.create(settings);

        // Verify CREATE TABLE SQL for the Iceberg sink parses correctly
        String createSinkSql = "CREATE TABLE sensor_data (" +
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
                ") WITH ('connector' = 'blackhole')";

        // Use blackhole connector to validate schema without needing Iceberg
        assertDoesNotThrow(() -> tableEnv.executeSql(createSinkSql));
    }
}
