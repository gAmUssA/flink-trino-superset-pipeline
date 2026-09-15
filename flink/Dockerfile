FROM flink:2.2.0-java17@sha256:7ecfab9d5e8ec6987a248b32f6605b5fe9bcb7347aea0d7b1bc3976588408681

ENV FLINK_VERSION=2.2.0
ENV ICEBERG_VERSION=1.10.1
ENV KAFKA_CONNECTOR_VERSION=4.0.1-2.0

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/flink/lib

# Flink connectors (4.x for Flink 2.x)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/${KAFKA_CONNECTOR_VERSION}/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-json/${FLINK_VERSION}/flink-json-${FLINK_VERSION}.jar

# Iceberg runtime for Flink 2.0 (covers Flink 2.x)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-flink-runtime-2.0/${ICEBERG_VERSION}/iceberg-flink-runtime-2.0-${ICEBERG_VERSION}.jar

# Iceberg AWS bundle (includes iceberg-aws + full AWS SDK v2, shaded)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/iceberg/iceberg-aws-bundle/${ICEBERG_VERSION}/iceberg-aws-bundle-${ICEBERG_VERSION}.jar

# Hadoop S3 support + HDFS classes (required by Iceberg FlinkCatalogFactory)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-s3-fs-hadoop/${FLINK_VERSION}/flink-s3-fs-hadoop-${FLINK_VERSION}.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-common/3.3.6/hadoop-common-3.3.6.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/hadoop/hadoop-hdfs-client/3.3.6/hadoop-hdfs-client-3.3.6.jar

# Caffeine cache (required by Iceberg REST catalog)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/com/github/ben-manes/caffeine/caffeine/3.2.3/caffeine-3.2.3.jar

# HTTP client (for REST catalog communication)
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/httpcomponents/client5/httpclient5/5.2.1/httpclient5-5.2.1.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/httpcomponents/core5/httpcore5/5.2.1/httpcore5-5.2.1.jar
RUN wget -q -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/httpcomponents/core5/httpcore5-h2/5.2.1/httpcore5-h2-5.2.1.jar

RUN chown -R flink:flink /opt/flink/lib
USER flink
