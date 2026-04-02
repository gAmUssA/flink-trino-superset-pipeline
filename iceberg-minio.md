# Apache Iceberg with MinIO and REST Catalog: Technical Guidelines

## Overview

Apache Iceberg is an open table format (OTF) that organizes collections of files as a single logical "table." Originally developed by Netflix in 2017 and donated to the Apache Software Foundation in 2018, Iceberg became a top-level Apache project in 2020.

Iceberg's design allows for several advanced capabilities:
- Schema evolution
- Hidden partitioning
- Partition layout evolution
- Time travel (querying historical versions)
- Version rollback

## Architecture Components

To implement Apache Iceberg, three key components are required:

1. **Catalog**: Maintains metadata files inventory
2. **Processing Engine**: Functions as query engine
3. **Storage Solution**: High-speed, scalable storage for data and metadata files

The reference implementation uses:
- **REST Catalog**: For metadata management
- **Apache Spark**: As the processing engine
- **MinIO**: Object storage for both data and metadata

## MinIO's Advantages for Iceberg

MinIO is particularly well-suited for Iceberg implementations:
- Handles both small and large files efficiently
- Offers high performance (349 GB/s GET and 177 GB/s PUT on 32 NVMe nodes)
- Provides strong consistency with immutable objects
- Includes inline erasure-code, bitrot hashing, and encryption
- Simplifies architecture by using the same storage for both metadata and data files

## Deployment with Docker Compose

The Docker Compose setup includes:

```yaml
version: "3"
services:
  spark-iceberg:
    image: tabulario/spark-iceberg
    # Configuration for Spark with Iceberg support
    depends_on:
      - rest
      - minio
    # Environment variables for AWS credentials to connect to MinIO
  rest:
    image: tabulario/iceberg-rest
    # REST catalog configuration
    environment:
      - CATALOG_WAREHOUSE=s3://warehouse/
      - CATALOG_IO__IMPL=org.apache.iceberg.aws.s3.S3FileIO
      - CATALOG_S3_ENDPOINT=http://minio:9000
  minio:
    image: minio/minio
    # MinIO configuration
    environment:
      - MINIO_ROOT_USER=admin
      - MINIO_ROOT_PASSWORD=password
    command: ["server", "/data", "--console-address", ":9001"]
  mc:
    # MinIO client for bucket setup
    # Creates and configures the warehouse bucket
```

The setup establishes a network where:
- The REST catalog connects to MinIO for metadata storage
- Spark connects to both the REST catalog and MinIO directly
- MinIO stores both metadata and data files

## Iceberg Data Architecture

Iceberg implements a three-level metadata architecture:

### Level 1: Metadata Files
- Contains schema and partition information
- Maintains list of snapshots
- Supports schema evolution and partition changes
- New file created for each table change

Example structure:
```json
{
  "format-version": 1,
  "table-uuid": "...",
  "location": "s3://warehouse/climate/weather",
  "current-schema-id": 0,
  "schemas": [...],
  "partition-specs": [...],
  "current-snapshot-id": 176629998480014857,
  "snapshots": [...]
}
```

### Level 2: Manifest Lists (Snapshots)
- Point-in-time snapshots of the table
- Links to Manifest files
- Enables time travel functionality
- Tracks added/deleted/existing files and rows

Example:
```json
{
  "manifest_path": "s3://warehouse/climate/weather/metadata/ce07e5bc-11f4-49b5-8ab1-90e85b2c211dm0.avro",
  "manifest_length": 6562,
  "partition_spec_id": 0,
  "added_snapshot_id": 176629998480014857,
  "added_data_files_count": 3,
  "existing_data_files_count": 0,
  "deleted_data_files_count": 0,
  "partitions": [...]
}
```

### Level 3: Manifest Files
- Point to actual data files
- Maintain partition information for data files
- Store column-level statistics (min/max values)
- Enable efficient query execution through filtering

### Data Files
- Typically stored in Parquet format
- Organized by partition in MinIO
- Contain the actual table data

## Configuration Details

The key configuration settings in the Docker Compose file:

1. **REST Catalog Configuration**:
    - `CATALOG_WAREHOUSE=s3://warehouse/` - Storage location
    - `CATALOG_IO__IMPL=org.apache.iceberg.aws.s3.S3FileIO` - S3 implementation
    - `CATALOG_S3_ENDPOINT=http://minio:9000` - MinIO endpoint

2. **MinIO Configuration**:
    - Standard S3-compatible credentials (admin/password)
    - Console on port 9001, S3 API on port 9000

3. **Spark Configuration**:
    - AWS credentials for MinIO access
    - Connection to REST catalog configured in conf file

## Table Creation and Structure

Tables are created using standard SQL syntax with Iceberg-specific extensions:

```sql
CREATE TABLE climate.weather (
  datetime timestamp,
  temp double,
  lat double,
  long double,
  cloud_coverage string,
  precip double,
  wind_speed double
)
USING iceberg
PARTITIONED BY (days(datetime))
```

The resulting structure in MinIO:

- `/warehouse/climate/weather/metadata/` - Contains metadata files
- `/warehouse/climate/weather/data/datetime_day=YYYY-MM-DD/` - Contains partitioned data files

## Implementation Benefits

- **Unified Storage**: Both metadata and data in MinIO
- **Scalability**: MinIO's performance suits workloads of any size
- **Cloud-Native**: Works with distributed computing frameworks
- **Open Format**: Prevents vendor lock-in
- **Advanced Features**: Time travel, schema evolution, hidden partitioning

This implementation showcases how MinIO provides an ideal foundation for modern data lake architectures built on open table formats like Apache Iceberg.