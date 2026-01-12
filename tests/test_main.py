import json
from main import app


def test_root_returns_hello_world():
    client = app.test_client()
    resp = client.get('/')
    assert resp.status_code == 200
    assert resp.data.decode('utf-8') == 'Hello World'


def test_hostname_returns_hostname_key():
    client = app.test_client()
    resp = client.get('/hostname')
    assert resp.status_code == 200
    data = resp.get_json()
    assert 'hostname' in data
    assert isinstance(data['hostname'], str)
