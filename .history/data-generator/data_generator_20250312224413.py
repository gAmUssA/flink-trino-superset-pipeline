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

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Kafka configuration
KAFKA_BOOTSTRAP_SERVERS = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
USER_ACTIVITY_TOPIC = 'user-activity'
SENSOR_DATA_TOPIC = 'sensor-data'

# Initialize Faker for generating realistic data
fake = Faker()

def create_kafka_producer():
    """Create and return a Kafka producer"""
    try:
        producer = KafkaProducer(
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda v: v.encode('utf-8') if v else None
        )
        logger.info(f"Connected to Kafka at {KAFKA_BOOTSTRAP_SERVERS}")
        return producer
    except Exception as e:
        logger.error(f"Failed to connect to Kafka: {e}")
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
