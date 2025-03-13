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
import org.apache.flink.api.java.tuple.Tuple7;
import org.apache.flink.connector.file.sink.FileSink;
import org.apache.flink.core.fs.Path;
import org.apache.flink.streaming.api.functions.sink.filesystem.rollingpolicies.DefaultRollingPolicy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;

/**
 * Flink job to process sensor data from Kafka and write to Iceberg.
 */
public class SensorDataProcessor {
    private static final Logger LOG = LoggerFactory.getLogger(SensorDataProcessor.class);
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();

    public static void main(String[] args) throws Exception {
        // Set up the streaming execution environment
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        
        // Configure Kafka source
        KafkaSource<String> source = KafkaSource.<String>builder()
                .setBootstrapServers("kafka:9092")
                .setTopics("sensor-data")
                .setGroupId("sensor-data-processor")
                .setStartingOffsets(OffsetsInitializer.earliest())
                .setValueOnlyDeserializer(new SimpleStringSchema())
                .build();

        // Read from Kafka
        DataStream<String> kafkaStream = env.fromSource(
                source,
                WatermarkStrategy.noWatermarks(),
                "Kafka Source"
        );

        // Parse JSON and convert to Tuple7
        DataStream<Tuple7<String, String, String, Double, Double, String, Double>> processedStream = 
            kafkaStream.map(new MapFunction<String, Tuple7<String, String, String, Double, Double, String, Double>>() {
                @Override
                public Tuple7<String, String, String, Double, Double, String, Double> map(String value) throws Exception {
                    JsonNode jsonNode = OBJECT_MAPPER.readTree(value);
                    
                    // Extract fields from JSON
                    String sensorId = jsonNode.get("sensor_id").asText();
                    String sensorType = jsonNode.get("sensor_type").asText();
                    
                    // Parse timestamp
                    String timestampStr = jsonNode.get("timestamp").asText();
                    
                    // Extract location data
                    JsonNode locationNode = jsonNode.get("location");
                    Double latitude = locationNode.get("lat").asDouble();
                    Double longitude = locationNode.get("lon").asDouble();
                    String facility = locationNode.get("facility").asText();
                    
                    // Extract sensor value
                    Double sensorValue = jsonNode.get("value").asDouble();
                    
                    return new Tuple7<>(sensorId, sensorType, timestampStr, latitude, longitude, facility, sensorValue);
                }
            });
        
        // Configure file sink
        final FileSink<Tuple7<String, String, String, Double, Double, String, Double>> sink = FileSink
            .forRowFormat(new Path("file:///tmp/sensor_data"), 
                new SimpleStringEncoder<Tuple7<String, String, String, Double, Double, String, Double>>() {
                    @Override
                    public byte[] encode(Tuple7<String, String, String, Double, Double, String, Double> element) {
                        return String.format("%s,%s,%s,%f,%f,%s,%f\n",
                            element.f0,  // sensor_id
                            element.f1,  // sensor_type
                            element.f2,  // timestamp
                            element.f3,  // latitude
                            element.f4,  // longitude
                            element.f5,  // facility
                            element.f6   // sensor_value
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
        env.execute("Sensor Data Processor");
    }
}
