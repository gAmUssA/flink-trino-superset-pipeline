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
CREATE TABLE IF NOT EXISTS user_activity_source (
  user_id STRING,
  event_type STRING,
  timestamp TIMESTAMP(3),
  session_id STRING,
  ip_address STRING,
  user_agent STRING,
  page_url STRING,
  referrer STRING,
  time_spent INT,
  element_id STRING,
  search_query STRING,
  results_count INT,
  order_id STRING,
  product_ids ARRAY<STRING>,
  total_amount DOUBLE,
  currency STRING,
  WATERMARK FOR timestamp AS timestamp - INTERVAL '5' SECOND
) WITH (
  'connector' = 'kafka',
  'topic' = 'user-activity',
  'properties.bootstrap.servers' = 'kafka:9092',
  'properties.group.id' = 'user-activity-processor',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'json',
  'json.ignore-parse-errors' = 'true',
  'json.timestamp-format.standard' = 'ISO-8601'
);

-- Define Iceberg Sink Table
CREATE TABLE IF NOT EXISTS user_activity_sink (
  user_id STRING,
  event_type STRING,
  event_time TIMESTAMP(3),
  session_id STRING,
  ip_address STRING,
  user_agent STRING,
  page_url STRING,
  referrer STRING,
  time_spent INT,
  element_id STRING,
  search_query STRING,
  results_count INT,
  order_id STRING,
  product_ids ARRAY<STRING>,
  total_amount DOUBLE,
  currency STRING,
  processing_time TIMESTAMP(3),
  PRIMARY KEY (user_id, session_id) NOT ENFORCED
) WITH (
  'format' = 'parquet',
  'write-format' = 'parquet'
);

-- Insert data from source to sink with transformation
INSERT INTO user_activity_sink 
SELECT 
  user_id,
  event_type,
  timestamp AS event_time,
  session_id,
  ip_address,
  user_agent,
  page_url,
  referrer,
  time_spent,
  element_id,
  search_query,
  results_count,
  order_id,
  product_ids,
  total_amount,
  currency,
  CURRENT_TIMESTAMP AS processing_time
FROM user_activity_source;
