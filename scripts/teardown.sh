#!/usr/bin/env bash
# Stop the Lab 03 gateway.
#   scripts/teardown.sh             # stop containers, keep the gateway's data volume
#   scripts/teardown.sh --volumes   # stop AND wipe the gateway's data volume (fresh start)

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

if [ "${1:-}" = "--volumes" ]; then
  echo "Stopping the gateway and wiping its data volume..."
  docker compose down --volumes
else
  echo "Stopping the gateway (data volume kept; use --volumes to wipe)..."
  docker compose down
fi
