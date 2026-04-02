package com.example;

import org.apache.flink.table.api.DataTypes;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.Schema;
import org.apache.flink.table.api.TableDescriptor;
import org.apache.flink.table.api.TableEnvironment;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Smoke tests for UserActivityProcessor.
 * Verifies that the job class loads, schemas are valid, and catalog SQL parses.
 */
class UserActivityProcessorTest {

    @Test
    void jobClassLoads() {
        assertDoesNotThrow(() -> Class.forName("com.example.UserActivityProcessor"));
    }

    @Test
    void kafkaSourceSchemaIsValid() {
        Schema schema = Schema.newBuilder()
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
                .watermark("timestamp", "`timestamp` - INTERVAL '5' SECOND")
                .build();

        assertNotNull(schema);
        assertEquals(16, schema.getColumns().size());
    }

    @Test
    void tableEnvironmentCreates() {
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode()
                .build();
        TableEnvironment tableEnv = TableEnvironment.create(settings);
        assertNotNull(tableEnv);
    }

    @Test
    void kafkaConnectorDescriptorBuilds() {
        TableDescriptor descriptor = TableDescriptor.forConnector("kafka")
                .schema(Schema.newBuilder()
                        .column("user_id", DataTypes.STRING())
                        .column("event_type", DataTypes.STRING())
                        .build())
                .option("connector", "kafka")
                .option("topic", "user-activity")
                .option("properties.bootstrap.servers", "localhost:9092")
                .option("format", "json")
                .build();

        assertNotNull(descriptor);
    }

    @Test
    void sinkTableSchemaCreatesWithBlackhole() {
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode()
                .build();
        TableEnvironment tableEnv = TableEnvironment.create(settings);

        // Validate the sink table schema using blackhole connector (no infra needed)
        String createSql = "CREATE TABLE user_activity (" +
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
                ") WITH ('connector' = 'blackhole')";

        assertDoesNotThrow(() -> tableEnv.executeSql(createSql));
    }
}
