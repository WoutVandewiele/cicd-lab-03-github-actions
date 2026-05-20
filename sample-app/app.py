"""Flask sample app for the Branching & PRs lab."""

import os

from flask import Flask, jsonify, request
import redis


def create_app(redis_client=None):
    app = Flask(__name__)
    app.redis = redis_client or redis.Redis.from_url(
        os.environ.get("REDIS_URL", "redis://localhost:6378/0"),
        decode_responses=True,
    )

    @app.get("/health")
    def health():
        return jsonify(status="ok")

    @app.get("/greet")
    def greet():
        name = request.args.get("name", "world")
        count = app.redis.incr(f"greet:{name}")
        return jsonify(message=f"Hello, {name}!", count=count)

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5051)
