FROM flink:2.3.0-java17@sha256:1939f31f9fd7c2ef0ecd47ed08d9d5b3efb8a3d1f512caa9a3dc7ac84f110bc0

ENV FLINK_VERSION=2.3.0
ENV ICEBERG_VERSION=1.12.0
ENV KAFKA_CONNECTOR_VERSION=5.0.0-2.2

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/flink/lib

# Flink connectors (4.x for Flink 2.x)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/${KAFKA_CONNECTOR_VERSION}/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-json/${FLINK_VERSION}/flink-json-${FLINK_VERSION}.jar

# Iceberg runtime for Flink 2.3
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-flink-runtime-2.3/${ICEBERG_VERSION}/iceberg-flink-runtime-2.3-${ICEBERG_VERSION}.jar

# Iceberg AWS bundle (includes iceberg-aws + full AWS SDK v2, shaded)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar

# Hadoop S3 support + HDFS classes (required by Iceberg FlinkCatalogFactory)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/${FLINK_VERSION}/flink-s3-fs-hadoop-${FLINK_VERSION}.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-common/3.3.6/hadoop-common-3.3.6.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-hdfs-client/3.3.6/hadoop-hdfs-client-3.3.6.jar

# Caffeine cache (required by Iceberg REST catalog)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/com/github/ben-manes/caffeine/caffeine/3.3.1/caffeine-3.3.1.jar

# HTTP client (for REST catalog communication)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/httpcomponents/client5/httpclient5/5.6.5/httpclient5-5.6.5.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/httpcomponents/core5/httpcore5/5.4.4/httpcore5-5.4.4.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/httpcomponents/core5/httpcore5-h2/5.4.4/httpcore5-h2-5.4.4.jar

RUN chown -R flink:flink /opt/flink/lib
USER flink
