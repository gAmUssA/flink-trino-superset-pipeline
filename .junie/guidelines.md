# Flink-Trino-Superset Data Pipeline

## Project Overview

This project demonstrates an end-to-end data pipeline using Apache Kafka, Apache Flink, Apache Iceberg, Trino, and Apache Superset. The pipeline ingests streaming data, processes it in real-time, stores it in a data lake format, and provides SQL querying and visualization capabilities.

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│             │    │             │    │             │    │             │    │             │
│  Data       │ -> │  Apache     │ -> │  Apache     │ -> │  Apache     │ -> │  Trino      │ -> ┌─────────────┐
│  Generator  │    │  Kafka      │    │  Flink      │    │  Iceberg    │    │  Query      │    │             │
│             │    │             │    │             │    │             │    │  Engine     │    │  Apache     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    │  Superset   │
                                                                                               │             │
                                                                                               └─────────────┘
```

### Data Flow

1. The data generator produces sample user activity and sensor data to Kafka topics
2. Flink jobs consume data from Kafka, process it, and write to Iceberg tables
3. Trino provides SQL querying capabilities over the Iceberg tables
4. Superset connects to Trino for data visualization and dashboarding

## Components

- **Apache Kafka**: Message broker for data ingestion
- **Apache Flink**: Stream processing framework
- **Apache Iceberg**: Table format for data lake storage
- **Trino**: Distributed SQL query engine
- **Apache Superset**: Data visualization and dashboarding

## Project Structure

```
.
├── data-generator/              # Data generator application
│   ├── Dockerfile               # Docker image definition
│   ├── requirements.txt         # Python dependencies
│   └── data_generator.py        # Data generator script
├── docker-compose.yml           # Docker Compose configuration
├── flink-jobs/                  # Flink processing jobs
│   ├── build.gradle.kts         # Gradle build configuration
│   ├── settings.gradle.kts      # Gradle settings
│   ├── create_tables.sql        # SQL script to create Iceberg tables
│   └── src/                     # Source code
│       └── main/
│           └── java/
│               └── com/
│                   └── example/
│                       ├── UserActivityProcessor.java  # User activity processor
│                       └── SensorDataProcessor.java    # Sensor data processor
├── trino/                       # Trino configuration
│   └── etc/                     # Trino configuration files
│       ├── config.properties    # Server configuration
│       ├── jvm.config           # JVM configuration
│       ├── node.properties      # Node configuration
│       ├── log.properties       # Logging configuration
│       └── catalog/             # Catalog configurations
│           ├── iceberg.properties  # Iceberg catalog
│           └── memory.properties   # Memory catalog
├── Makefile                     # Project automation
├── requirements.adoc            # Project requirements
└── README.adoc                  # Project documentation
```

## Development Guidelines

### General Guidelines

- Use Java 21 for building the project
- Use Gradle with Kotlin for build scripts
- Use SDKMAN for managing SDKs

### Documentation Guidelines

- Use AsciiDoc (*.adoc) for documentation and use emoji for better readability
- Use one sentence per line in AsciiDoc
- PRD (Product Requirements Document) should be written in AsciiDoc
- Convert Markdown files to AsciiDoc
- Use Mermaid diagrams inside docs

### Makefile Guidelines

- Use make files when need to execute more than one command
- For Makefiles use emoji and ascii colors for better readability
- Makefile should include smoketest task to validate startup of all docker containers
- Don't use sleep in makefiles, use wait/retry logic instead

### Docker Guidelines

- Prefer to use OrbStack for managing docker containers (instead of Docker Desktop)
- For managing docker containers use Docker Compose and don't add version attribute for docker-compose.yaml file

### Kafka Guidelines

- For Kafka in Docker use apache/kafka:3.9.0 image in Kraft mode without Zookeeper
- Confluent Platform (Schema Registry) version is 7.9.0
- Use Apache Kafka® and Kafka Streams version 3.9.0

### Flink Guidelines

- Use Apache Flink version 1.20
- For org.apache.flink:flink-connector-kafka dependency use version 3.4.0-1.20
- Prefer to use Flink Table API or Flink SQL instead of Flink DataStream API

## Getting Started

1. Clone the repository
2. Start the services with `make up`
3. Create Iceberg tables with `make create-tables`
4. Build and submit Flink jobs with `make deploy-flink-jobs`
5. Set up Superset with `make setup-superset`

## Accessing the Services

- Kafka UI: http://localhost:8080
- Minio Console: http://localhost:9001 (minioadmin/minioadmin)
- Flink Dashboard: http://localhost:8081
- Trino UI: http://localhost:8082
- Superset: http://localhost:8088 (admin/admin)