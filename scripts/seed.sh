#!/usr/bin/env bash
# Seed Part 1's deliberately-broken state into the working tree.
#
# Run this once at the start of Part 1, then hunt the planted issues with the
# linters (yamllint, shellcheck, actionlint, ign-lint, scripts/validate.sh). Every
# planted issue is a mistake a real Ignition project picks up — a brittle binding,
# a runaway poll rate, a hand-edited resource with broken JSON, and so on.
#
# Reset back to a clean tree at any time with:
#   git restore . && rm -f .github/workflows/example.yml

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

# 2. shellcheck SC2086 — unquoted variable in scripts/scan.sh
p = pathlib.Path("scripts/scan.sh")
s = p.read_text()
s = s.replace('"$URL/data/api/v1/scan/projects"',
              '$URL/data/api/v1/scan/projects', 1)
p.write_text(s)

# 4 + 5 + 6. ign-lint — a brittle/dangling component reference, a runaway poll,
# and a mis-named component, all in the view
view = pathlib.Path(
    "projects/lab-project/com.inductiveautomation.perspective/views/pages/overview/view.json")
s = view.read_text()
# The Discharge tile's value used a clean runScript binding. Re-point it at a sibling
# tile by a brittle *relative path* — to a component that no longer exists (someone
# renamed "SuctionPressure" to "Suction"). This is the classic "renamed a component and
# a binding silently broke" bug: it trips BOTH BadComponentReferenceRule (brittle '../'
# traversal) AND ComponentReferenceValidationRule (the target doesn't resolve).
s = s.replace("runScript('lab.display.format_reading', 0, -6.5, '°C')",
              "{../../SuctionPressure.Value.props.text}", 1)
# The Clock polls four times a second instead of once — PollingIntervalRule.
s = s.replace("now(1000)", "now(250)", 1)
# The Power KPI tile gets a snake_case rename — the classic "quick rename in the
# Designer that ignores the naming standard". NamePatternRule wants PascalCase
# components (severity: error in rule_config.json).
s = s.replace('"name": "Power"', '"name": "power_tile"', 1)
view.write_text(s)

# 7. scripts/validate.sh — malformed JSON: a trailing comma left in project.json by a hand-edit
p = pathlib.Path("projects/lab-project/project.json")
s = p.read_text()
s = s.replace('"parent": ""', '"parent": "",', 1)   # trailing comma → invalid JSON
p.write_text(s)
PY

# 3. actionlint — a throwaway workflow pinned to a deprecated action
mkdir -p .github/workflows
cat > .github/workflows/example.yml <<'YML'
name: Example workflow
on: workflow_dispatch
jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: echo "hello"
YML

cat <<'EOF'
Seeded issues into the working tree:
  1. docker-compose.yml              — yamllint    (trailing whitespace)
  2. scripts/scan.sh                     — shellcheck  (SC2086, unquoted variable)
  3. .github/workflows/example.yml   — actionlint  (deprecated actions/checkout@v2)
  4. overview/view.json (Discharge)  — ign-lint    (brittle + dangling component reference)
  5. overview/view.json (Clock)      — ign-lint    (poll faster than the 1000ms floor)
  6. overview/view.json (Power tile) — ign-lint    (snake_case component name)
  7. project.json                    — validate.sh (malformed JSON: trailing comma)

Find them with the linters. When you're done, reset to a clean tree with:
  git restore . && rm -f .github/workflows/example.yml
EOF
