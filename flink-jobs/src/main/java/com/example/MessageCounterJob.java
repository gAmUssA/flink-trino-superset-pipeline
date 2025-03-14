package com.example;

import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.windowing.assigners.TumblingProcessingTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.connectors.kafka.FlinkKafkaConsumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Properties;

/**
 * Flink job to count messages from a Kafka topic and print the count every 10 seconds.
 * Uses DataStream API to avoid SQL parsing issues.
 */
public class MessageCounterJob {
    private static final Logger LOG = LoggerFactory.getLogger(MessageCounterJob.class);

    public static void main(String[] args) throws Exception {
        // Set up the streaming environment
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        // Configure Kafka consumer
        Properties properties = new Properties();
        properties.setProperty("bootstrap.servers", "kafka:9092");
        properties.setProperty("group.id", "message-counter-job");

        // Create Kafka consumer
        FlinkKafkaConsumer<String> kafkaConsumer = new FlinkKafkaConsumer<>(
            "sensor-data",                // topic
            new SimpleStringSchema(),     // deserializer
            properties                    // consumer properties
        );

        // Set to start from earliest offset
        kafkaConsumer.setStartFromEarliest();

        // Create a DataStream from Kafka
        DataStream<String> stream = env.addSource(kafkaConsumer);

        // Count messages in 10-second windows
        DataStream<Tuple2<String, Integer>> counts = stream
            .map(new MapFunction<String, Tuple2<String, Integer>>() {
                @Override
                public Tuple2<String, Integer> map(String value) {
                    return new Tuple2<>("Message count", 1);
                }
            })
            .keyBy(value -> value.f0)
            .window(TumblingProcessingTimeWindows.of(Time.seconds(10)))
            .sum(1);

        // Print the results
        counts.print();

        LOG.info("Message Counter Job submitted");

        // Execute the job
        env.execute("Message Counter Job");
    }
}
