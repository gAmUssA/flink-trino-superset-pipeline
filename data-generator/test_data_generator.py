"""Smoke tests for the data generator.

Validates that event generation works, schemas are correct,
and JSON serialization produces valid output.
No Kafka connection required.
"""

import json
from datetime import datetime

from data_generator import generate_user_activity, generate_sensor_data


def test_user_activity_has_required_fields():
    user_id, event = generate_user_activity()
    assert isinstance(user_id, str)
    assert 'user_id' in event
    assert 'event_type' in event
    assert 'timestamp' in event
    assert 'session_id' in event
    assert 'ip_address' in event
    assert 'user_agent' in event


def test_user_activity_event_types():
    expected = {'page_view', 'click', 'search', 'purchase', 'login', 'logout'}
    seen = set()
    for _ in range(200):
        _, event = generate_user_activity()
        seen.add(event['event_type'])
    assert seen == expected, f"Missing event types: {expected - seen}"


def test_user_activity_purchase_has_products():
    for _ in range(200):
        _, event = generate_user_activity()
        if event['event_type'] == 'purchase':
            assert 'order_id' in event
            assert 'product_ids' in event
            assert isinstance(event['product_ids'], list)
            assert len(event['product_ids']) >= 1
            assert 'total_amount' in event
            assert event['total_amount'] > 0
            return
    assert False, "No purchase event generated in 200 attempts"


def test_sensor_data_has_required_fields():
    sensor_id, data = generate_sensor_data()
    assert isinstance(sensor_id, str)
    assert sensor_id.startswith('sensor-')
    assert 'sensor_id' in data
    assert 'sensor_type' in data
    assert 'timestamp' in data
    assert 'location' in data
    assert 'battery_level' in data
    assert 'reading' in data
    assert 'unit' in data


def test_sensor_data_location_is_nested():
    _, data = generate_sensor_data()
    loc = data['location']
    assert isinstance(loc, dict)
    assert 'lat' in loc
    assert 'lon' in loc
    assert 'facility' in loc
    assert isinstance(loc['lat'], float)
    assert isinstance(loc['lon'], float)
    assert isinstance(loc['facility'], str)


def test_sensor_data_types():
    expected = {'temperature', 'humidity', 'pressure', 'light', 'motion'}
    seen = set()
    for _ in range(200):
        _, data = generate_sensor_data()
        seen.add(data['sensor_type'])
    assert seen == expected, f"Missing sensor types: {expected - seen}"


def test_sensor_readings_in_range():
    ranges = {
        'temperature': (-10, 40),
        'humidity': (0, 100),
        'pressure': (970, 1030),
        'light': (0, 1000),
        'motion': (0, 1),
    }
    for _ in range(500):
        _, data = generate_sensor_data()
        lo, hi = ranges[data['sensor_type']]
        assert lo <= data['reading'] <= hi, \
            f"{data['sensor_type']} reading {data['reading']} out of range [{lo}, {hi}]"


def test_timestamps_are_iso8601():
    _, user_event = generate_user_activity()
    _, sensor_data = generate_sensor_data()
    # Should not raise
    datetime.fromisoformat(user_event['timestamp'])
    datetime.fromisoformat(sensor_data['timestamp'])


def test_json_serializable():
    _, user_event = generate_user_activity()
    _, sensor_data = generate_sensor_data()
    # Should not raise
    user_json = json.dumps(user_event)
    sensor_json = json.dumps(sensor_data)
    # Round-trip
    assert json.loads(user_json)['user_id'] == user_event['user_id']
    assert json.loads(sensor_json)['sensor_id'] == sensor_data['sensor_id']
