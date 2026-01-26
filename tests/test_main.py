import json
import base64
import os
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


def test_index_requires_basic_auth(monkeypatch):
    monkeypatch.setenv("AUTH_ENABLED", "true")
    monkeypatch.setenv("BASIC_AUTH_USER", "admin")
    monkeypatch.setenv("BASIC_AUTH_PASS", "secret")

    client = app.test_client()
    resp = client.get('/index')
    assert resp.status_code == 403

    # Simulate HTTPS via X-Forwarded-Proto
    resp = client.get('/index', headers={"X-Forwarded-Proto": "https"})
    assert resp.status_code == 401

    token = base64.b64encode(b"admin:secret").decode("utf-8")
    resp = client.get('/index', headers={
        "Authorization": f"Basic {token}",
        "X-Forwarded-Proto": "https",
    })
    assert resp.status_code == 200
    assert b"Simple REST Service" in resp.data


def test_host_restriction(monkeypatch):
    monkeypatch.setenv("ALLOWED_HOST", "example.com")

    client = app.test_client()
    resp = client.get('/', headers={"Host": "127.0.0.1"})
    assert resp.status_code == 403

    resp = client.get('/', headers={"Host": "example.com"})
    assert resp.status_code == 200
