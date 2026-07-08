#!/usr/bin/env bash
#
# Prepare Part 2 — set the shipped answer aside and drop in a starter skeleton.
#
# Part 2 has you REBUILD .github/workflows/ci.yml from scratch. This script does
# only the two mechanical bits, so you can get straight to the interesting work:
#   1. moves the finished ci.yml out to .github/ci-reference.yml (your answer key)
#   2. writes a bare two-job skeleton to .github/workflows/ci.yml for you to flesh out
#
# It does NOT write the real steps — the TODOs in the skeleton are yours to fill
# in across Part 2, steps 0-3. Every action is announced as it happens.
#
# Re-running is safe: if the answer is already set aside, it won't clobber anything.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

WORKFLOW=".github/workflows/ci.yml"
REFERENCE=".github/ci-reference.yml"

# Colour the step headers only when writing to a real terminal.
if [ -t 1 ]; then C=$'\033[1;36m'; B=$'\033[1m'; R=$'\033[0m'; else C=''; B=''; R=''; fi
say()  { printf '\n%s▸ %s%s\n' "$C" "$1" "$R"; }
note() { printf '  %s\n' "$1"; }

# --- guard: right directory? ---
if [ ! -d .github ]; then
  echo "error: run this from the lab repo root (no .github/ directory here)." >&2
  exit 1
fi

# --- guard: already prepared? ---
if [ -f "$REFERENCE" ]; then
  say "Already prepared — nothing to do."
  note "$REFERENCE exists, so the shipped answer is already set aside."
  [ -f "$WORKFLOW" ] && note "$WORKFLOW is in place — keep building it out."
  exit 0
fi

if [ ! -f "$WORKFLOW" ]; then
  echo "error: $WORKFLOW not found — expected the shipped workflow to move." >&2
  exit 1
fi

# --- step 1: set the answer aside ---
say "Step 1/2 — set the shipped answer aside"
note "Running: ${B}git mv $WORKFLOW $REFERENCE${R}"
note "Keeps the finished workflow as a reference you'll check against in step 5,"
note "while taking it out of .github/workflows/ so GitHub no longer runs it."
git mv "$WORKFLOW" "$REFERENCE"

# --- step 2: write the starter skeleton ---
say "Step 2/2 — write a starter skeleton to $WORKFLOW"
note "A bare two-job skeleton (validate + lint) with TODOs — the real steps are"
note "yours to type across steps 0-3. Nothing here does the exercise for you."
cat > "$WORKFLOW" <<'YAML'
name: CI

# TODO (step 1): refine this trigger — add a `paths:` filter so docs-only PRs are
# skipped, plus a `push: branches: [main]` backstop. See the assignment.
on: [pull_request]

# Least-privilege default; individual jobs override if they need more.
permissions:
  contents: read

jobs:
  # Job ids become the status-check names branch protection matches on —
  # keep `validate` and `lint` stable (renaming them orphans the required checks).

  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # TODO: run scripts/validate.sh

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # TODO (step 0): set up Python 3.12, then install the pinned tools
      #                (pip install yamllint==1.35.1 ign-lint==0.6.1)
      # TODO: run each linter — yamllint, actionlint, shellcheck, ign-lint
      # TODO (step 2): add `docker compose config -q` as the final lint step
YAML

say "Done."
note "Answer key : $REFERENCE"
note "Your file  : $WORKFLOW  (starter skeleton — flesh out the TODOs)"
note "Next: open $WORKFLOW and work through Part 2, steps 1-3."
