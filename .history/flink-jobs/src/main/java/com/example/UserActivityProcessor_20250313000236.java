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
import org.apache.flink.api.common.serialization.SimpleStringEncoder;
import org.apache.flink.api.java.tuple.Tuple8;
import org.apache.flink.connector.file.sink.FileSink;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.functions.sink.filesystem.rollingpolicies.DefaultRollingPolicy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.TimeUnit;

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

        // Parse JSON and convert to Tuple8
        DataStream<Tuple8<String, String, String, String, String, String, String, Double>> processedStream = 
            kafkaStream.map(new MapFunction<String, Tuple8<String, String, String, String, String, String, String, Double>>() {
                @Override
                public Tuple8<String, String, String, String, String, String, String, Double> map(String value) throws Exception {
                    JsonNode jsonNode = OBJECT_MAPPER.readTree(value);
                    
                    // Extract fields from JSON
                    String userId = jsonNode.get("user_id").asText();
                    String eventType = jsonNode.get("event_type").asText();
                    
                    // Parse timestamp
                    String timestampStr = jsonNode.get("timestamp").asText();
                    
                    String sessionId = jsonNode.get("session_id").asText();
                    String ipAddress = jsonNode.get("ip_address").asText();
                    String userAgent = jsonNode.get("user_agent").asText();
                    
                    // Handle optional fields
                    String pageUrl = jsonNode.has("page_url") ? jsonNode.get("page_url").asText() : "";
                    Double totalAmount = jsonNode.has("total_amount") ? jsonNode.get("total_amount").asDouble() : 0.0;
                    
                    return new Tuple8<>(userId, eventType, timestampStr, sessionId, ipAddress, userAgent, pageUrl, totalAmount);
                }
            });
        
        // Configure file sink
        final FileSink<Tuple8<String, String, String, String, String, String, String, Double>> sink = FileSink
            .forRowFormat(new Path("file:///tmp/user_activity"), 
                new SimpleStringEncoder<Tuple8<String, String, String, String, String, String, String, Double>>() {
                    @Override
                    public byte[] encode(Tuple8<String, String, String, String, String, String, String, Double> element) {
                        return String.format("%s,%s,%s,%s,%s,%s,%s,%f\n",
                            element.f0,  // user_id
                            element.f1,  // event_type
                            element.f2,  // timestamp
                            element.f3,  // session_id
                            element.f4,  // ip_address
                            element.f5,  // user_agent
                            element.f6,  // page_url
                            element.f7   // total_amount
                        ).getBytes();
                    }
                })
            .withRollingPolicy(
                DefaultRollingPolicy.builder()
                    .withRolloverInterval(TimeUnit.MINUTES.toMillis(15))
                    .withInactivityInterval(TimeUnit.MINUTES.toMillis(5))
                    .withMaxPartSize(1024 * 1024 * 1024)
                    .build())
            .build();
        
        // Add sink to the pipeline
        processedStream.sinkTo(sink);
        
        // Also print the data to stdout for debugging
        processedStream.print();

        // Execute the Flink job
        env.execute("User Activity Processor");
    }
}
