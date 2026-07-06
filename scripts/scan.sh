#!/usr/bin/env bash
# Tell the gateway to scan project files and pick up changes you've made under
# projects/ — no restart needed. Run this after editing a view or a script.
#
# Why this exists: a running gateway does NOT auto-detect edits to the
# bind-mounted project files; you have to trigger a scan (or restart it).
#
# One-time setup: the scan API needs an API key. In the gateway UI
# (http://localhost:8088) go to Config → Security → API Keys → Create, give it
# Project Scan permission, and add the value to .env as:
#     IGNITION_API_KEY=<value>

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Load .env (gateway URL + API key) if present.
if [ -f .env ]; then
  set -a
  # .env is generated locally; there's nothing for shellcheck to follow.
  # shellcheck source=/dev/null
  . ./.env
  set +a
fi

URL="${IGNITION_URL:-http://localhost:8088}"
KEY="${IGNITION_API_KEY:-}"

if [ -z "$KEY" ]; then
  echo "No IGNITION_API_KEY set in .env — can't trigger a scan over the API."
  echo "Create one in the gateway UI ($URL):"
  echo "  Config → Security → API Keys → Create  (with Project Scan permission)"
  echo "then add it to .env as  IGNITION_API_KEY=<value>  and re-run  scripts/scan.sh."
  echo "(Or just restart the gateway:  docker compose restart  — slower, no key needed.)"
  exit 1
fi

code=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "X-Ignition-API-Token: $KEY" \
  -H "Accept: application/json" \
  --max-time 30 \
  "$URL/data/api/v1/scan/projects")

if [ "$code" -ge 200 ] && [ "$code" -lt 300 ]; then
  echo "✓ Project scan triggered (HTTP $code) — the gateway now has your latest changes."
else
  echo "✗ Scan failed (HTTP $code)." >&2
  echo "  Check that IGNITION_API_KEY in .env is valid and has Project Scan permission." >&2
  exit 1
fi
