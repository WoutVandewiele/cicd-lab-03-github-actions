#!/usr/bin/env bash
# Seed Part 1's deliberately-broken state into the working tree.
#
# Run this once at the start of Part 1, then hunt the planted issues with the
# linters (yamllint, shellcheck, actionlint, ign-lint, ops/validate.sh). There
# are SIX issues — one per tool, plus a second ign-lint finding.
#
# Reset back to a clean tree at any time with:
#   git restore . && rm -f .github/workflows/example.yml
#
# Idempotent-ish: re-running won't stack duplicates for most issues, but the
# cleanest reset is the git command above.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

command -v python3 >/dev/null 2>&1 || {
  echo "Error: python3 is required to seed the project." >&2
  exit 1
}

# Tracked-file edits are applied with python3 (portable; no sed -i differences).
python3 - <<'PY'
import pathlib

# 1. yamllint — trailing whitespace in docker-compose.yml
p = pathlib.Path("docker-compose.yml")
s = p.read_text()
s = s.replace("    container_name: lab03-ignition\n",
              "    container_name: lab03-ignition   \n", 1)
p.write_text(s)

# 2. shellcheck SC2086 — unquoted variable in ops/scan.sh
p = pathlib.Path("ops/scan.sh")
s = p.read_text()
s = s.replace('"$URL/data/api/v1/scan/projects"',
              '$URL/data/api/v1/scan/projects', 1)
p.write_text(s)

# 4 + 5. ign-lint — a snake_case component name and a sub-floor poll, both in the view
view = pathlib.Path(
    "projects/lab-project/com.inductiveautomation.perspective/views/pages/overview/view.json")
s = view.read_text()
s = s.replace('"name": "SystemPill"', '"name": "system_pill"', 1)   # NamePatternRule
s = s.replace("now(1000)", "now(250)", 1)                           # PollingIntervalRule
view.write_text(s)

# 6. ops/validate.sh — a Jython-2 print statement that fails Python-3 parsing
code = pathlib.Path(
    "projects/lab-project/ignition/script-python/lab/display/code.py")
s = code.read_text().rstrip() + (
    "\n\n\n"
    "def _debug(value):\n"
    '    print "reading:", value   # Jython-2 statement form; not valid Python 3\n'
)
code.write_text(s)
PY

# 3. actionlint — a workflow using a deprecated action + an undefined env var
mkdir -p .github/workflows
cat > .github/workflows/example.yml <<'YML'
name: Example workflow
on: workflow_dispatch
jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: echo "${{ env.MISSING_VAR }}"
YML

cat <<'EOF'
Seeded 6 issues into the working tree:
  1. docker-compose.yml              — yamllint   (trailing whitespace)
  2. ops/scan.sh                     — shellcheck (SC2086, unquoted variable)
  3. .github/workflows/example.yml   — actionlint (deprecated checkout@v2 + undefined env)
  4. overview/view.json              — ign-lint   (NamePatternRule: snake_case component)
  5. overview/view.json              — ign-lint   (PollingIntervalRule: poll faster than 1000ms)
  6. lab/display/code.py             — validate.sh (Jython-2 print statement)

Find them with the linters. When you're done, reset to a clean tree with:
  git restore . && rm -f .github/workflows/example.yml
EOF
