package com.example;

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.Schema;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableDescriptor;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.table.api.DataTypes;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Flink job to count messages from a Kafka topic and print the count every 10 seconds.
 * Uses Table API as per project guidelines.
 */
public class MessageCounterJob {
    private static final Logger LOG = LoggerFactory.getLogger(MessageCounterJob.class);

    public static void main(String[] args) throws Exception {
        // Set up the table environment
        EnvironmentSettings settings = EnvironmentSettings.newInstance()
                .inStreamingMode()
                .build();
        TableEnvironment tableEnv = TableEnvironment.create(settings);

        // Configure Kafka source table
        tableEnv.createTemporaryTable("sensor_source", TableDescriptor.forConnector("kafka")
                .schema(Schema.newBuilder()
                        .column("message", DataTypes.STRING())
                        .build())
                .option("connector", "kafka")
                .option("topic", "sensor-data")
                .option("properties.bootstrap.servers", "kafka:9092")
                .option("properties.group.id", "message-counter-job")
                .option("scan.startup.mode", "earliest-offset")
                .option("format", "json")
                .option("json.ignore-parse-errors", "true")
                .option("json.timestamp-format.standard", "ISO-8601")
                .build());

        // Create a SQL query that counts messages in 10-second tumbling windows
        String windowedCountQuery = 
            "SELECT " +
            "  TUMBLE_START(PROCTIME(), INTERVAL '10' SECOND) AS window_start, " +
            "  TUMBLE_END(PROCTIME(), INTERVAL '10' SECOND) AS window_end, " +
            "  COUNT(*) AS message_count " +
            "FROM sensor_source " +
            "GROUP BY TUMBLE(PROCTIME(), INTERVAL '10' SECOND)";

        // Execute the query and get the result table
        Table resultTable = tableEnv.sqlQuery(windowedCountQuery);

        // Print the schema for debugging
        LOG.info("Result schema: {}", resultTable.getSchema());

        // Print the results
        tableEnv.createTemporaryView("message_counts", resultTable);
        tableEnv.executeSql("SELECT * FROM message_counts").print();

        LOG.info("Message Counter Job submitted");
    }
}
