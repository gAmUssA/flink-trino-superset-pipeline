# Flink-Trino-Superset Data Pipeline

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

## Components

- **Apache Kafka**: Message broker for data ingestion
- **Apache Flink**: Stream processing framework
- **Apache Iceberg**: Table format for data lake storage
- **Trino**: Distributed SQL query engine
- **Apache Superset**: Data visualization and dashboarding

## Prerequisites

- Docker and Docker Compose
- Java 11+ (for building Flink jobs)
- Maven (for building Flink jobs)

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/flink-trino-superset-pipeline.git
cd flink-trino-superset-pipeline
```

### 2. Start the Services

```bash
docker-compose up -d
```

This will start all the required services:
- Zookeeper (port 2181)
- Kafka (port 9092)
- Kafka UI (port 8080)
- Minio (ports 9000, 9001)
- Flink JobManager (port 8081)
- Flink TaskManager
- MySQL (port 3306)
- Iceberg REST Catalog (port 8181)
- Trino (port 8082)
- Superset (port 8088)
- Data Generator

### 3. Create Iceberg Tables

Connect to the Trino CLI:

```bash
docker exec -it trino-coordinator trino --server localhost:8080 --catalog iceberg
```

Run the SQL script to create tables:

```sql
source /opt/flink/usrlib/create_tables.sql
```

Alternatively, you can run the SQL script directly:

```bash
docker exec -it trino-coordinator trino --server localhost:8080 --catalog iceberg -f /opt/flink/usrlib/create_tables.sql
```

### 4. Submit Flink Jobs

Build the Flink jobs:

```bash
cd flink-jobs
mvn clean package
```

Submit the jobs to Flink:

```bash
docker cp target/flink-iceberg-pipeline-1.0-SNAPSHOT.jar flink-jobmanager:/opt/flink/usrlib/
docker exec -it flink-jobmanager flink run -c com.example.UserActivityProcessor /opt/flink/usrlib/flink-iceberg-pipeline-1.0-SNAPSHOT.jar
docker exec -it flink-jobmanager flink run -c com.example.SensorDataProcessor /opt/flink/usrlib/flink-iceberg-pipeline-1.0-SNAPSHOT.jar
```

### 5. Set Up Superset

Access Superset at http://localhost:8088 and log in with:
- Username: admin
- Password: admin

Configure a connection to Trino:
1. Go to Data -> Databases -> + Database
2. Select "Trino" as the database type
3. Set the SQLAlchemy URI to: `trino://admin@trino-coordinator:8080/iceberg`
4. Test the connection and save

Create datasets and dashboards:
1. Go to Data -> Datasets -> + Dataset
2. Select the Trino connection and choose tables from the iceberg.warehouse schema
3. Create visualizations and dashboards based on the data

## Accessing the Services

- **Kafka UI**: http://localhost:8080
- **Minio Console**: http://localhost:9001 (minioadmin/minioadmin)
- **Flink Dashboard**: http://localhost:8081
- **Trino UI**: http://localhost:8082
- **Superset**: http://localhost:8088 (admin/admin)

## Data Flow

1. The data generator produces sample user activity and sensor data to Kafka topics
2. Flink jobs consume data from Kafka, process it, and write to Iceberg tables
3. Trino provides SQL querying capabilities over the Iceberg tables
4. Superset connects to Trino for data visualization and dashboarding

## Project Structure

```
.
├── data-generator/              # Data generator application
│   ├── Dockerfile               # Docker image definition
│   ├── requirements.txt         # Python dependencies
│   └── data_generator.py        # Data generator script
├── docker-compose.yml           # Docker Compose configuration
├── flink-jobs/                  # Flink processing jobs
│   ├── pom.xml                  # Maven project configuration
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
└── README.md                    # Project documentation
```

## Troubleshooting

- **Services not starting**: Check Docker logs with `docker-compose logs <service-name>`
- **Kafka topics not created**: Ensure Kafka and Zookeeper are running properly
- **Flink jobs failing**: Check Flink logs in the Flink Dashboard
- **Trino queries failing**: Verify Iceberg REST Catalog and Minio are accessible
- **Superset connection issues**: Ensure Trino is running and accessible

## License

This project is licensed under the MIT License - see the LICENSE file for details.
