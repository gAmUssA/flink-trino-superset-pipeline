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
import java.util.Map;

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

        // Parse JSON and convert to RowData
        DataStream<RowData> rowDataStream = kafkaStream.map(new MapFunction<String, RowData>() {
            @Override
            public RowData map(String value) throws Exception {
                JsonNode jsonNode = OBJECT_MAPPER.readTree(value);
                
                GenericRowData row = new GenericRowData(7);
                
                // Extract fields from JSON
                row.setField(0, StringData.fromString(jsonNode.get("sensor_id").asText()));
                row.setField(1, StringData.fromString(jsonNode.get("sensor_type").asText()));
                
                // Parse timestamp
                String timestampStr = jsonNode.get("timestamp").asText();
                Instant instant = Instant.parse(timestampStr);
                LocalDateTime dateTime = LocalDateTime.ofInstant(instant, ZoneId.systemDefault());
                row.setField(2, TimestampData.fromLocalDateTime(dateTime));
                
                // Extract location data
                JsonNode locationNode = jsonNode.get("location");
                row.setField(3, locationNode.get("lat").asDouble());
                row.setField(4, locationNode.get("lon").asDouble());
                row.setField(5, StringData.fromString(locationNode.get("facility").asText()));
                
                // Extract sensor value
                row.setField(6, jsonNode.get("value").asDouble());
                
                return row;
            }
        });

        // Configure Iceberg sink
        Map<String, String> props = new HashMap<>();
        props.put("type", "iceberg");
        props.put("catalog-type", "hive_metastore");
        props.put("uri", "thrift://hive-metastore:9083");
        props.put("warehouse", "s3a://warehouse");
        props.put("fs.s3a.endpoint", "http://minio:9000");
        props.put("fs.s3a.access.key", "minioadmin");
        props.put("fs.s3a.secret.key", "minioadmin");
        props.put("fs.s3a.path.style.access", "true");
        props.put("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem");
        
        // Create Hadoop configuration
        org.apache.hadoop.conf.Configuration hadoopConf = new org.apache.hadoop.conf.Configuration();
        hadoopConf.set("fs.s3a.endpoint", "http://minio:9000");
        hadoopConf.set("fs.s3a.access.key", "minioadmin");
        hadoopConf.set("fs.s3a.secret.key", "minioadmin");
        hadoopConf.set("fs.s3a.path.style.access", "true");
        hadoopConf.set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem");
        
        // Create table loader
        TableLoader tableLoader = TableLoader.fromHadoopTable(
                "s3a://warehouse/sensor_data",
                hadoopConf
        );
        
        // Write to Iceberg
        FlinkSink.forRowData(rowDataStream)
                .tableLoader(tableLoader)
                .writeParallelism(1) // Adjust based on your needs
                .append();
        
        // Also print the data to stdout for debugging
        rowDataStream.print();

        // Execute the Flink job
        env.execute("Sensor Data Processor");
    }
}
