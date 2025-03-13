package com.example;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.data.GenericRowData;
import org.apache.flink.table.data.RowData;
import org.apache.flink.table.data.StringData;
import org.apache.flink.table.data.TimestampData;
import org.apache.iceberg.flink.TableLoader;
import org.apache.iceberg.flink.sink.FlinkSink;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

/**
 * Flink job to process user activity data from Kafka and write to Iceberg.
 */
public class UserActivityProcessor {
    private static final Logger LOG = LoggerFactory.getLogger(UserActivityProcessor.class);
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    public static void main(String[] args) throws Exception {
        // Set up the streaming execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        
        // Configure Kafka source
        KafkaSource<String> source = KafkaSource.<String>builder()
                .setBootstrapServers("kafka:9092")
                .setTopics("user-activity")
                .setGroupId("user-activity-processor")
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setValueOnlyDeserializer(new SimpleStringSchema())
                .build();

        // Read from Kafka
        DataStream<String> kafkaStream = env.fromSource(
                source,
                WatermarkStrategy.noWatermarks(),
                "Kafka Source"
        );

        // Parse JSON and convert to RowData
        DataStream<RowData> rowDataStream = kafkaStream.map(new MapFunction<String, RowData>() {
            @Override
            public RowData map(String value) throws Exception {
                JsonNode jsonNode = OBJECT_MAPPER.readTree(value);
                
                GenericRowData row = new GenericRowData(8);
                
                // Extract fields from JSON
                row.setField(0, StringData.fromString(jsonNode.get("user_id").asText()));
                row.setField(1, StringData.fromString(jsonNode.get("event_type").asText()));
                
                // Parse timestamp
                String timestampStr = jsonNode.get("timestamp").asText();
                Instant instant = Instant.parse(timestampStr);
                LocalDateTime dateTime = LocalDateTime.ofInstant(instant, ZoneId.systemDefault());
                row.setField(2, TimestampData.fromLocalDateTime(dateTime));
                
                row.setField(3, StringData.fromString(jsonNode.get("session_id").asText()));
                row.setField(4, StringData.fromString(jsonNode.get("ip_address").asText()));
                row.setField(5, StringData.fromString(jsonNode.get("user_agent").asText()));
                
                // Handle optional fields based on event type
                if (jsonNode.has("page_url")) {
                    row.setField(6, StringData.fromString(jsonNode.get("page_url").asText()));
                } else {
                    row.setField(6, null);
