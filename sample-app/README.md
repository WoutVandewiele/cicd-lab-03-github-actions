# Sample app — Flask + Redis

A tiny two-service web app. The subject of this lab's branching and PR exercises.

- `app.py` — Flask with `/health` and `/greet?name=<name>`. `/greet` increments a per-name counter stored in Redis.
- `tests/test_app.py` — pytest tests using a fake redis client.

Python is the medium; the lab is really about Git workflows, branch strategies, and PR review. You can complete every exercise without knowing Flask.

## Run it

```bash
docker compose up -d
curl http://localhost:1/health
curl "http://localhost:5051/greet?name=Ada"
```

## Test it

```bash
pip install -r sample-app/requirements.txt
pytest sample-app/tests -q
```
