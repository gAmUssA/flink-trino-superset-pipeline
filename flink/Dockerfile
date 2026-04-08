FROM flink:1.20.3-java17@sha256:b90e8c9d3a0ee5cda479eedc9fe1c1788d7ab3574114fd3d49ccf6b5bd2ebfe6

ENV FLINK_VERSION=1.20.0
ENV ICEBERG_VERSION=1.8.1
ENV KAFKA_CONNECTOR_VERSION=3.4.0-1.20

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/flink/lib

# Flink connectors
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/${KAFKA_CONNECTOR_VERSION}/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-json/${FLINK_VERSION}/flink-json-${FLINK_VERSION}.jar

# Iceberg runtime (includes core + Flink integration)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-flink-runtime-1.20/${ICEBERG_VERSION}/iceberg-flink-runtime-1.20-${ICEBERG_VERSION}.jar

# Iceberg AWS bundle (includes iceberg-aws + full AWS SDK v2, shaded)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar

# Hadoop S3 support + HDFS classes (required by Iceberg FlinkCatalogFactory)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/${FLINK_VERSION}/flink-s3-fs-hadoop-${FLINK_VERSION}.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-common/3.3.6/hadoop-common-3.3.6.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-hdfs-client/3.3.6/hadoop-hdfs-client-3.3.6.jar

# Caffeine cache (required by Iceberg REST catalog)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/com/github/ben-manes/caffeine/caffeine/3.1.8/caffeine-3.1.8.jar

# HTTP client (for REST catalog communication)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/httpcomponents/client5/httpclient5/5.2.1/httpclient5-5.2.1.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/httpcomponents/core5/httpcore5/5.2.1/httpcore5-5.2.1.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/httpcomponents/core5/httpcore5-h2/5.2.1/httpcore5-h2-5.2.1.jar

RUN chown -R flink:flink /opt/flink/lib
USER flink
