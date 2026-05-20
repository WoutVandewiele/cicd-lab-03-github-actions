import fakeredis
import pytest

from app import create_app


@pytest.fixture
def client():
    app = create_app(redis_client=fakeredis.FakeRedis(decode_responses=True))
    app.testing = True
    return app.test_client()


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_greet_increments_counter(client):
    first = client.get("/greet?name=Ada").get_json()
    second = client.get("/greet?name=Ada").get_json()
    assert first == {"message": "Hello, Ada!", "count": 1}
    assert second == {"message": "Hello, Ada!", "count": 2}


def test_greet_defaults_to_world(client):
    response = client.get("/greet").get_json()
    assert response["message"] == "Hello, world!"
