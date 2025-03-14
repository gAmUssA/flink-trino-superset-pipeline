-- Set up the Iceberg catalog
CREATE CATALOG iceberg_catalog WITH (
  'type'='iceberg',
  'catalog-impl'='org.apache.iceberg.rest.RESTCatalog',
  'uri'='http://iceberg-rest:8181',
  'warehouse'='s3://warehouse/',
  'io-impl'='org.apache.iceberg.aws.s3.S3FileIO',
  's3.endpoint'='http://minio:9000',
  's3.path-style-access'='true',
  'client.region'='us-east-1',
  's3.access-key-id'='minioadmin',
  's3.secret-access-key'='minioadmin'
);

-- Use the catalog and create database
USE CATALOG iceberg_catalog;
CREATE DATABASE IF NOT EXISTS db;
USE db;

-- Define Kafka Source Table
CREATE TABLE IF NOT EXISTS sensor_source (
  sensor_id STRING,
  sensor_type STRING,
  timestamp TIMESTAMP(3),
  location ROW<lat DOUBLE, lon DOUBLE, facility STRING>,
  battery_level DOUBLE,
  reading DOUBLE,
  unit STRING,
  WATERMARK FOR timestamp AS timestamp - INTERVAL '5' SECOND
) WITH (
  'connector' = 'kafka',
  'topic' = 'sensor-data',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'sensor-data-processor',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'json',
  'json.ignore-parse-errors' = 'true',
  'json.timestamp-format.standard' = 'ISO-8601'
);

-- Define Iceberg Sink Table
CREATE TABLE IF NOT EXISTS sensor_sink (
  sensor_id STRING,
  sensor_type STRING,
  event_time TIMESTAMP(3),
  latitude DOUBLE,
  longitude DOUBLE,
  facility STRING,
  battery_level DOUBLE,
  reading DOUBLE,
  unit STRING,
  processing_time TIMESTAMP(3),
  PRIMARY KEY (sensor_id) NOT ENFORCED
) WITH (
  'format' = 'parquet',
  'write-format' = 'parquet'
);

-- Insert data from source to sink with transformation
INSERT INTO sensor_sink 
SELECT 
  sensor_id,
  sensor_type,
  timestamp AS event_time,
  location.lat AS latitude,
  location.lon AS longitude,
  location.facility AS facility,
  battery_level,
  reading,
  unit,
  CURRENT_TIMESTAMP AS processing_time
FROM sensor_source;
