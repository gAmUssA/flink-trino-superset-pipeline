#!/usr/bin/env python3
"""
Data Generator for Kafka-Flink-Iceberg-Trino-Superset Pipeline
Generates sample data and sends it to Kafka topics
"""

import json
import logging
import os
import random
import time
import configparser
import sys
from datetime import datetime, timedelta
from pathlib import Path

from faker import Faker
from confluent_kafka import Producer
from confluent_kafka.admin import AdminClient, NewTopic

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Faker for generating realistic data
fake = Faker()

def load_config(env_type='local'):
    """Load configuration from property files"""
    config_dir = Path(__file__).parent.parent / 'config' / env_type

    # Debug: Print the resolved config directory path and check if it exists
    logger.info(f"Resolved config directory path: {config_dir}")
    logger.info(f"Config directory exists: {config_dir.exists()}")
    logger.info(f"Current working directory: {os.getcwd()}")
    logger.info(f"Directory contents: {os.listdir(Path(__file__).parent.parent)}")

    if not config_dir.exists():
        logger.error(f"Configuration directory not found: {config_dir}")
        # Try an alternative path
        alt_config_dir = Path('/app/config') / env_type
        logger.info(f"Trying alternative config directory: {alt_config_dir}")
        if alt_config_dir.exists():
            logger.info(f"Alternative config directory found: {alt_config_dir}")
            config_dir = alt_config_dir
        else:
            logger.error(f"Alternative config directory not found: {alt_config_dir}")
            sys.exit(1)

    # Load Kafka configuration
    kafka_config = {}
    kafka_config_path = config_dir / 'kafka.properties'
    if kafka_config_path.exists():
        parser = configparser.ConfigParser(strict=False)
        with open(kafka_config_path, 'r') as f:
            # Add a default section header for configparser
            config_content = '[DEFAULT]\n' + f.read()
        parser.read_string(config_content)
        kafka_config = dict(parser['DEFAULT'])
        logger.info(f"Loaded Kafka configuration from {kafka_config_path}")
    else:
        logger.warning(f"Kafka configuration file not found: {kafka_config_path}")

    # Load topic configuration
    topics_config = {}
    topics_config_path = config_dir / 'topics.properties'
    if topics_config_path.exists():
        parser = configparser.ConfigParser(strict=False)
        with open(topics_config_path, 'r') as f:
            # Add a default section header for configparser
            config_content = '[DEFAULT]\n' + f.read()
        parser.read_string(config_content)
        topics_config = dict(parser['DEFAULT'])
        logger.info(f"Loaded topics configuration from {topics_config_path}")
    else:
        logger.warning(f"Topics configuration file not found: {topics_config_path}")

    return kafka_config, topics_config

def create_kafka_producer(kafka_config, max_retries=30, retry_interval=5):
    """Create and return a Confluent Kafka producer with retry mechanism"""
    # Use environment variables as fallback
    bootstrap_servers = kafka_config.get('bootstrap.servers', 
                                         os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092'))

    # Create a copy of the config dict to avoid modifying the original
    producer_config = kafka_config.copy()
    admin_config = kafka_config.copy()

    # Add client ID for better tracking
    producer_config['client.id'] = 'data-generator'

    retries = 0
    while retries < max_retries:
        try:
            # Create Confluent Kafka producer
            producer = Producer(producer_config)

            # Test the connection by creating an AdminClient
            admin_client = AdminClient(admin_config)
            metadata = admin_client.list_topics(timeout=10)

            logger.info(f"Successfully connected to Kafka at {bootstrap_servers}")
            return producer
        except Exception as e:
            retries += 1
            logger.warning(f"Failed to connect to Kafka (attempt {retries}/{max_retries}): {e}")
            if retries < max_retries:
                logger.info(f"Retrying in {retry_interval} seconds...")
                time.sleep(retry_interval)
            else:
                logger.error(f"Max retries ({max_retries}) reached. Could not connect to Kafka.")
                raise

def generate_user_activity():
    """Generate a random user activity event"""
    user_id = str(random.randint(1, 1000))
    event_types = ['page_view', 'click', 'search', 'purchase', 'login', 'logout']
    event_type = random.choice(event_types)

    # Base event data
    event = {
        'user_id': user_id,
        'event_type': event_type,
        'timestamp': datetime.now().isoformat(),
        'session_id': fake.uuid4(),
        'ip_address': fake.ipv4(),
        'user_agent': fake.user_agent()
    }

    # Add event-specific data
    if event_type == 'page_view':
        event['page_url'] = fake.uri()
        event['referrer'] = fake.uri() if random.random() > 0.3 else None
        event['time_spent'] = random.randint(5, 300)
    elif event_type == 'click':
        event['element_id'] = f"btn-{fake.word()}"
        event['page_url'] = fake.uri()
    elif event_type == 'search':
        event['search_query'] = fake.sentence(nb_words=random.randint(1, 5))
        event['results_count'] = random.randint(0, 100)
    elif event_type == 'purchase':
        event['order_id'] = fake.uuid4()
        event['product_ids'] = [fake.uuid4() for _ in range(random.randint(1, 5))]
        event['total_amount'] = round(random.uniform(10, 500), 2)
        event['currency'] = 'USD'

    return user_id, event

def generate_sensor_data():
    """Generate random IoT sensor data"""
    sensor_id = f"sensor-{random.randint(1, 100)}"
    sensor_types = ['temperature', 'humidity', 'pressure', 'light', 'motion']
    sensor_type = random.choice(sensor_types)

    # Base sensor data
    data = {
        'sensor_id': sensor_id,
        'sensor_type': sensor_type,
        'timestamp': datetime.now().isoformat(),
        'location': {
            'lat': float(fake.latitude()),
            'lon': float(fake.longitude()),
            'facility': fake.company()
        },
        'battery_level': random.uniform(0, 100)
    }

    # Add sensor-specific readings
    if sensor_type == 'temperature':
        data['reading'] = round(random.uniform(-10, 40), 1)  # Celsius
        data['unit'] = 'C'
    elif sensor_type == 'humidity':
        data['reading'] = round(random.uniform(0, 100), 1)  # Percentage
        data['unit'] = '%'
    elif sensor_type == 'pressure':
        data['reading'] = round(random.uniform(970, 1030), 1)  # hPa
        data['unit'] = 'hPa'
    elif sensor_type == 'light':
        data['reading'] = round(random.uniform(0, 1000), 1)  # Lux
        data['unit'] = 'lux'
    elif sensor_type == 'motion':
        data['reading'] = random.choice([0, 1])  # Binary (detected or not)
        data['unit'] = 'binary'

    return sensor_id, data

def delivery_callback(err, msg):
    """Callback function for message delivery reports"""
    if err:
        logger.error(f'Message delivery failed: {err}')
    else:
        logger.debug(f'Message delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}')

def main():
    """Main function to generate and send data to Kafka"""
    # Get environment type from environment variable or default to local
    env_type = os.environ.get('KAFKA_ENV', 'local')
    logger.info(f"Using {env_type} environment configuration")

    # Load configuration
    kafka_config, topics_config = load_config(env_type)

    # Get topic names from configuration or use defaults
    user_activity_topic = topics_config.get('topic.user-activity', 'user-activity')
    sensor_data_topic = topics_config.get('topic.sensor-data', 'sensor-data')

    producer = None
    try:
        # Try to connect to Kafka with retries
        bootstrap_servers = kafka_config.get('bootstrap.servers', 'localhost:9092')
        logger.info(f"Attempting to connect to Kafka at {bootstrap_servers}...")
        producer = create_kafka_producer(kafka_config)

        # Create topics if they don't exist
        logger.info(f"Ensuring topics exist: {user_activity_topic}, {sensor_data_topic}")

        # Main data generation loop
        logger.info("Starting data generation")
        message_count = 0

        while True:
            # Generate and send user activity data
            if random.random() > 0.4:  # 60% chance to generate user activity
                user_id, user_activity = generate_user_activity()
                # Convert data to JSON string
                user_activity_json = json.dumps(user_activity)
                # Send to Kafka
                producer.produce(
                    user_activity_topic,
                    key=user_id,
                    value=user_activity_json,
                    callback=delivery_callback
                )
                logger.debug(f"Sent user activity: {user_activity}")

            # Generate and send sensor data
            if random.random() > 0.3:  # 70% chance to generate sensor data
                sensor_id, sensor_data = generate_sensor_data()
                # Convert data to JSON string
                sensor_data_json = json.dumps(sensor_data)
                # Send to Kafka
                producer.produce(
                    sensor_data_topic,
                    key=sensor_id,
                    value=sensor_data_json,
                    callback=delivery_callback
                )
                logger.debug(f"Sent sensor data: {sensor_data}")

            # Poll to handle callbacks
            producer.poll(0)

            # Flush messages periodically
            message_count += 1
            if message_count % 10 == 0:
                producer.flush()
                logger.info(f"Generated {message_count} messages so far")

            # Sleep for a random interval to simulate realistic data flow
            time.sleep(random.uniform(0.1, 1.0))

    except KeyboardInterrupt:
        logger.info("Data generation stopped by user")
    except Exception as e:
        logger.error(f"Error in data generation: {e}")
    finally:
        if producer:
            try:
                producer.flush()
                logger.info("Kafka producer flushed and closed")
            except Exception as e:
                logger.error(f"Error closing Kafka producer: {e}")

if __name__ == "__main__":
    main()
