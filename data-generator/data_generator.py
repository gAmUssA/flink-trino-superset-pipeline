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
from datetime import datetime, timedelta

from faker import Faker
from kafka import KafkaProducer
from kafka.errors import NoBrokersAvailable

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Kafka configuration
KAFKA_BOOTSTRAP_SERVERS = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
USER_ACTIVITY_TOPIC = os.environ.get('KAFKA_USER_ACTIVITY_TOPIC', 'user-activity')
SENSOR_DATA_TOPIC = os.environ.get('KAFKA_SENSOR_DATA_TOPIC', 'sensor-data')

# Initialize Faker for generating realistic data
fake = Faker()

def create_kafka_producer(max_retries=30, retry_interval=5):
    """Create and return a Kafka producer with retry mechanism"""
    retries = 0
    while retries < max_retries:
        try:
            producer = KafkaProducer(
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                key_serializer=lambda v: v.encode('utf-8') if v else None,
                # Add some additional configurations for better reliability
                reconnect_backoff_ms=1000,
                reconnect_backoff_max_ms=10000,
                request_timeout_ms=30000
            )
            logger.info(f"Successfully connected to Kafka at {KAFKA_BOOTSTRAP_SERVERS}")
            return producer
        except NoBrokersAvailable as e:
            retries += 1
            logger.warning(f"Failed to connect to Kafka (attempt {retries}/{max_retries}): {e}")
            if retries < max_retries:
                logger.info(f"Retrying in {retry_interval} seconds...")
                time.sleep(retry_interval)
            else:
                logger.error(f"Max retries ({max_retries}) reached. Could not connect to Kafka.")
                raise
        except Exception as e:
            logger.error(f"Unexpected error connecting to Kafka: {e}")
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

def main():
    """Main function to generate and send data to Kafka"""
    producer = None
    try:
        # Try to connect to Kafka with retries
        logger.info(f"Attempting to connect to Kafka at {KAFKA_BOOTSTRAP_SERVERS}...")
        producer = create_kafka_producer()
        
        # Create topics if they don't exist
        logger.info(f"Ensuring topics exist: {USER_ACTIVITY_TOPIC}, {SENSOR_DATA_TOPIC}")
        
        # Main data generation loop
        logger.info("Starting data generation")
        message_count = 0
        
        while True:
            # Generate and send user activity data
            if random.random() > 0.4:  # 60% chance to generate user activity
                user_id, user_activity = generate_user_activity()
                producer.send(USER_ACTIVITY_TOPIC, key=user_id, value=user_activity)
                logger.debug(f"Sent user activity: {user_activity}")
            
            # Generate and send sensor data
            if random.random() > 0.3:  # 70% chance to generate sensor data
                sensor_id, sensor_data = generate_sensor_data()
                producer.send(SENSOR_DATA_TOPIC, key=sensor_id, value=sensor_data)
                logger.debug(f"Sent sensor data: {sensor_data}")
            
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
                producer.close()
                logger.info("Kafka producer closed")
            except Exception as e:
                logger.error(f"Error closing Kafka producer: {e}")

if __name__ == "__main__":
    main()
