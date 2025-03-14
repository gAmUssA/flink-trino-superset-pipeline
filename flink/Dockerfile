FROM flink:1.20.1-java17@sha256:bf1af6406c4f4ad8faa46efe2b3d0a0bf811d1034849c42c1e3484712bc83505

# Set environment variables
ENV FLINK_VERSION=1.20.0
ENV ICEBERG_VERSION=1.8.1
ENV KAFKA_CONNECTOR_VERSION=3.4.0-1.20

# Install required packages
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        unzip \
        maven \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create directories for dependencies
RUN mkdir -p /opt/flink/plugins/iceberg
RUN mkdir -p /opt/flink/plugins/s3

# Download and install Flink Kafka connector
RUN wget -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/${KAFKA_CONNECTOR_VERSION}/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar

# Download and install Flink JSON
RUN wget -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-json/${FLINK_VERSION}/flink-json-${FLINK_VERSION}.jar

# Download and install Iceberg dependencies
RUN wget -P /opt/flink/plugins/iceberg/ https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-flink-runtime-1.20/${ICEBERG_VERSION}/iceberg-flink-runtime-1.20-${ICEBERG_VERSION}.jar
RUN wget -P /opt/flink/plugins/iceberg/ https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-aws/${ICEBERG_VERSION}/iceberg-aws-${ICEBERG_VERSION}.jar
RUN wget -P /opt/flink/plugins/iceberg/ https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-core/${ICEBERG_VERSION}/iceberg-core-${ICEBERG_VERSION}.jar

# Download and install AWS S3 dependencies
RUN wget -P /opt/flink/plugins/s3/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/${FLINK_VERSION}/flink-s3-fs-hadoop-${FLINK_VERSION}.jar
RUN wget -P /opt/flink/plugins/s3/ https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-aws/3.3.6/hadoop-aws-3.3.6.jar
RUN wget -P /opt/flink/plugins/s3/ https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-common/3.3.6/hadoop-common-3.3.6.jar
RUN wget -P /opt/flink/plugins/s3/ https://repo.maven.apache.org/maven2/software/amazon/awssdk/s3/2.25.12/s3-2.25.12.jar

# Download and install Jackson for JSON processing
RUN wget -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.15.3/jackson-databind-2.15.3.jar
RUN wget -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/com/fasterxml/jackson/datatype/jackson-datatype-jsr310/2.15.3/jackson-datatype-jsr310-2.15.3.jar

# Set permissions
RUN chown -R flink:flink /opt/flink/plugins
RUN chown -R flink:flink /opt/flink/lib

# Switch back to flink user
USER flink
