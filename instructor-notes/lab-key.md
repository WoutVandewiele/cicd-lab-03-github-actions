# Lab 03 — instructor answer key

> **Do not read this before you've attempted the You-do solo.** Half the value of this lab
> is the diagnostic skill — running each tool, reading the output, deciding what to do.

Covers all three parts of the workshop: linters, GitHub Actions, self-hosted runners.

---

## Part 1 — Linters

### The seeded broken state

The shipped `main` is **clean** — no planted issues, and `lab-project` passes ign-lint with
**zero** findings. The broken state is produced by **`ops/seed.sh`**, which plants the issues
below into the working tree (no git tags, no branches — just run the script). Participants
reset with `git restore . && rm -f .github/workflows/example.yml`.

The Overview view lives at
`projects/lab-project/com.inductiveautomation.perspective/views/pages/overview/view.json`;
the project metadata at `projects/lab-project/project.json`; the script libraries at
`projects/lab-project/ignition/script-python/lab/{display,util}/code.py`.

### The planted issues

**1. `docker-compose.yml` — yamllint (trailing whitespace).** `seed.sh` appends trailing
spaces to the `container_name: lab03-ignition` line. yamllint flags `trailing-spaces`.
(line-length is *disabled* in `.yamllint.yml`, so the long compose env lines don't flag —
that's deliberate, and the subject of the config sub-task below.)
**Fix:** strip the trailing whitespace.

**2. `ops/scan.sh` — shellcheck SC2086 (unquoted variable).** `seed.sh` unquotes the scan
URL: `"$URL/data/api/v1/scan/projects"` → `$URL/data/api/v1/scan/projects`. shellcheck flags
`SC2086` ("Double quote to prevent globbing and word splitting").
**Fix:** re-quote it — `"$URL/data/api/v1/scan/projects"`.

**3. `.github/workflows/example.yml` — actionlint (deprecated action).** `seed.sh` writes a
throwaway workflow that pins a stale action:

```yaml
name: Example workflow
on: workflow_dispatch
jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: echo "hello"
```

actionlint flags `actions/checkout@v2` as too old to run on GitHub Actions.
**Fix:** bump it to `actions/checkout@v4`, or **delete the file** — acceptable, example
workflows aren't required.

**4. Overview `view.json` — ign-lint brittle + dangling component reference (the headline
finding).** `seed.sh` re-points the **Discharge** tile's value away from its clean
`runScript('lab.display.format_reading', …)` binding and at a *sibling tile by a brittle
relative path* — to a component that no longer exists:

```
{../../SuctionPressure.Value.props.text}
```

This is the classic "someone renamed a component and a binding silently broke" bug, and it
trips **two** rules at once:
- `BadComponentReferenceRule` (error) — the `../` traversal couples this binding to the
  view's structure; reorganise the tree and it breaks.
- `ComponentReferenceValidationRule` (error) — `SuctionPressure` doesn't resolve to a real
  component (it was renamed to `Suction`).

Run: `ign-lint --config rule_config.json --files "projects/**/view.json"`.
**Fix:** restore a real data binding (the original `runScript('lab.display.format_reading', 0,
-6.5, '°C')`). Teaching point: don't reach across the component tree by relative path — bind
to a real data source, a `view.custom` property, or message handling.

**5. Overview `view.json` — ign-lint `PollingIntervalRule` (runaway poll).** `seed.sh`
changes the Clock binding `now(1000)` → `now(250)`. `rule_config.json` sets
`minimum_interval = 1000` (ms), so a 250 ms poll (4×/second) is under the floor.
**Fix:** restore `now(1000)` (or slower). Teaching point: fast polls multiply across a
deployed HMI and hammer the gateway.

**6. Overview `view.json` — ign-lint `NamePatternRule` (snake_case component).** `seed.sh`
renames the **Power** KPI tile to `power_tile`. Components must be PascalCase (severity
`error` in `rule_config.json`), so ign-lint flags it and suggests `PowerTile`.
**Fix:** rename it back to `Power`. Teaching point: naming drift is the most common
real-world ign-lint finding — a quick rename in the Designer that ignores the team
convention, invisible until someone greps for the old name.

**7. `project.json` — `ops/validate.sh` (malformed JSON).** `seed.sh` leaves a **trailing
comma** after the last property in `project.json` (`"parent": ""` → `"parent": "",`) — exactly
the slip a hand-edit of a tracked resource produces. `ops/validate.sh` runs `json.load` over
every `*.json` under `projects/`, so it fails to parse and the script exits 1 (the red PR
signal). (`validate.sh` also parses every `code.py` as Python 3, so a genuine script syntax
error fails it the same way.)
**Fix:** remove the trailing comma so `project.json` is valid JSON again.

### Config sub-task: `.yamllint.yml` comment

`.yamllint.yml` disables `line-length`. The participant should **extend the existing comment**
explaining *why* — the compose file has long environment-variable lines (gateway config,
connection strings, JVM args) that would blow past the limit, and wrapping them hurts
readability more than it helps.

### Clean end state

After Part 1: trailing whitespace stripped; `ops/scan.sh` variable re-quoted; `example.yml`
fixed or deleted; the Discharge binding restored to its `runScript(...)` data source, the
Clock restored to `now(1000)`, and the Power tile renamed back to `Power`; the trailing
comma removed from `project.json`; the `.yamllint.yml` comment extended. Every linter silent and `ops/validate.sh` exits 0.

### Grading

- **All linters silent.** `yamllint`, `shellcheck`, `actionlint`, `ign-lint` produce zero
  output and `ops/validate.sh` exits 0 on the final state.
- **Justified config changes.** If they disabled a `yamllint`/`ign-lint` rule, the commit
  message or config comment should explain why.
- **No "fixed by deleting it" cheats.** Deleting the Clock, the Discharge binding, or the
  Power tile to silence ign-lint is wrong — restore them; only the *reference*, the *poll
  rate*, and the *name* were broken, not the components. Removing `example.yml` is fine
  (it was optional).
- **The view still loads.** Editing a binding is a `view.json` edit — confirm they didn't
  break the JSON or leave a dangling reference.

### Stretch — pre-commit

`.pre-commit-config.yaml` wires yamllint, shellcheck, actionlint, and ign-lint. A participant
who completes the stretch can `pre-commit install`, make a bad change (e.g. set a binding to
`now(250)`, or point one at a non-existent sibling), and watch the commit get blocked by
ign-lint. If the commit succeeds anyway: did they run `pre-commit install`? Is
`.git/hooks/pre-commit` populated?

### Debrief crib

- *"Which linter would have caught your most recent bug?"* — Push past "we don't have bugs."
- *"When does linting hurt?"* — Style-as-errors that block merge; slower than the dev loop;
  rules the team never agreed to.
- *"Which ign-lint rules map to bugs you've shipped?"* — Usually inconsistent component naming
  and runaway poll rates. `BadComponentReferenceRule` (relative `.getParent()`/`.getSibling()`
  traversal) provokes the best discussion — it silently breaks when a view is restructured.

---

## Part 2 — GitHub Actions

### Reference end-state workflow

The shipped [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) is the canonical end
state. A participant's final state should be **structurally equivalent** — same triggers,
same jobs, same step ordering. Cosmetic differences (step names, comment density) are fine.

```yaml
on:
  pull_request:
    paths: ["projects/**", "ops/**", "docker-compose.yml", ".github/workflows/**", ".yamllint.yml", "rule_config.json"]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  lint:       # yamllint + actionlint + shellcheck ops/*.sh + ign-lint + docker compose config
    runs-on: ubuntu-latest
    timeout-minutes: 5
  validate:   # ops/validate.sh — every project *.json valid, every code.py parses
    runs-on: ubuntu-latest
    timeout-minutes: 5
```

Note the job ids are bare `lint` / `validate` with **no `name:` override** — branch
protection matches required checks by the displayed name, so the ids must match what
participants selected in You-do step 4. A participant who adds pretty `name:` labels to
their jobs after configuring protection has orphaned their required checks (see the trap
below).

The `validate` job is the gateway-free green/red signal; `ign-lint` (PyPI `ign-lint==0.6.1`,
from `bw-design-group/ignition-lint`) is the Ignition-native linter for Perspective
`view.json` — it needs Python 3.10+, hence the pinned `setup-python` `"3.12"`.

### Must-haves

- **`permissions: contents: read`** at the workflow level. Missing → `issue:` comment.
- **`paths:` filter** on `pull_request` covering `projects/**`, `ops/**`, and `rule_config.json`.
  A docs-only PR must be **skipped**. If their docs PR runs the full workflow, the filter's wrong.
  (After step 4 that same skipped PR will hang on "Expected — waiting for status" — that's the
  trap callout working as intended, not a bug in their workflow. The no-op-twin stretch resolves it.)
- **`ign-lint` step** in `lint` and a **`validate` job** running `ops/validate.sh`.
- **CI badge** in `README.md` (often missed; `nitpick:` if absent).
- **Required check** on `main` — both `lint` and `validate`.

### Common mistakes

- **Hardcoding a secret value** in a debug step → real `issue:`, and rotate it.
- **Path filter too narrow** (`projects/lab-project/project.json`) — skips on view changes;
  use directory globs and include `rule_config.json`.
- **Path filter too broad** (`["**"]`) — defeats the purpose.
- **Forgetting Python 3.10+ for `ign-lint`** — drop/older `setup-python` → install or run fails.
- **Quoting the version as `3.12` not `"3.12"`** — YAML coerces it to the float `3.1`.

### Acceptable variations

- **Job ordering** — lint-then-validate or the reverse; the jobs are independent.
- **Missing `timeout-minutes`** — `nitpick:`; point at the 6-hour hung-job default.
- **Skipping a linter** — ask why. "We have no shell scripts" is acceptable; "I forgot" isn't.
  `ign-lint` and `validate` are not optional — they're the point.

### Stretch — matrix over views

A correct stretch has a `strategy.matrix` running `ign-lint` once per view (one entry today;
the pattern is the point). Verify Python is still pinned `"3.12"`. Matrixing `validate` is
overkill — it already walks every file in one pass. Genuinely optional; don't penalize a
single globbed step.

### `pull_request_target`

Participants were asked to **read**, not implement. If you see `pull_request_target` in their
workflow, dig in — they probably copy-pasted without understanding the privilege-escalation risk.

### Debrief crib

- *"Where does it run?"* — An ephemeral runner per job; jobs share no state without artifacts/caching.
- *"Step fails midway?"* — Later steps skip, the job fails, `needs:` downstream jobs skip.
  `continue-on-error: true` overrides.
- *"Required-check implications?"* — The *people* part is harder than the tech. Who maintains
  CI? Who fixes it when it's flaky?
- *"Why pin pip by version but actions by tag?"* — A moved tag is a supply-chain vector;
  SHA-pinning plus Dependabot is the hardened answer. Expect this to land hardest with people
  who deploy inside customer networks — connect it forward to the Part 3 runner discussion.

### Debugging tips

- **"Workflow not running on my PR."** Check the `paths:` filter and the PR source branch.
- **"My docs-only PR is stuck on *Expected — waiting for status*."** The paths-filter ×
  required-check interaction from the step 4 callout: a skipped required check never reports,
  so the PR waits forever. Options: the no-op twin workflow (stretch), an admin merge, or
  accepting it for a lab repo. This is the single most common real-world surprise with
  required checks — lean into it.
- **"ign-lint install/run fails."** Almost always Python version — needs 3.10+. Confirm the
  `--files` glob is quoted (`"projects/**/view.json"`) so the shell doesn't expand it first.
- **"validate fails but the views look fine."** It also parses every `code.py` as Python 3 —
  a syntax error in a script fails the job. Read the output; it names the file.
- **"shellcheck not found."** Needs the apt-get install step; not preinstalled everywhere.

---

## Part 3 — Self-hosted runners

This part is a guided demo + discussion; the full register/route/de-register flow is an
optional take-home. The interesting content is the **security discussion**, not the mechanics.

### The runner command, annotated

```bash
docker run -d --rm \                              # detached, auto-clean on exit
  --name lab03-runner \                           # name for `docker logs`/`docker stop`
  -e REPO_URL="https://github.com/<user>/<repo>" \
  -e RUNNER_NAME="lab03-$(whoami)" \              # appears in the GitHub UI
  -e RUNNER_TOKEN="$RUNNER_TOKEN" \               # registration token (short-lived)
  -e LABELS="self-hosted,local-lab03" \           # used by runs-on matching
  -e EPHEMERAL=true \                             # auto-terminate after one job
  -v /var/run/docker.sock:/var/run/docker.sock \  # so the job can use Docker
  myoung34/github-runner:latest                   # community-maintained image
```

The mounted Docker socket is convenient but a real trade-off — anything in the runner can use
the host's Docker daemon (effectively root on the host). In production, prefer DinD or rootless
Docker over a mounted socket.

### Common stumbles (if you run the hands-on)

- **Runner not picking up jobs** — is it running (`docker ps`)? do its labels match `runs-on:`?
  is it green in *Settings → Actions → Runners*?
- **Registration token expired** — they're short-lived; regenerate via `gh api -X POST .../registration-token`.
- **shellcheck not installed on the runner** — expected; the image ships only what you put on it.
  GitHub-hosted runners have a lot preinstalled; yours doesn't. A good lesson, not a bug.
- **Runner stops after one job** — expected with `EPHEMERAL=true`.

### Removing an offline runner

```bash
gh api "repos/<user>/<repo>/actions/runners" --jq '.runners[] | {id, name, status}'
gh api -X DELETE "repos/<user>/<repo>/actions/runners/<runner-id>"
```

### Debrief crib

- *"Which of your deploys would require self-hosted?"* — Push for specifics. "Our gateway is
  behind the customer's VPN; GitHub-hosted physically can't reach it" beats "maybe."
- *"Guardrails on a production runner?"* — Look for at least three: ephemeral lifecycle;
  repo-scope only; network-isolated; short-lived tokens via OIDC; restricted PR triggers.
- *"Where does the runner sit for an Ignition shop?"* — Most realistic: a dedicated build VM
  with network access to the gateway, **not** the gateway server itself (you don't want CI
  competing with the runtime). We come back to this in Lab 05.
- *"When is self-hosted definitely not worth it?"* — Small teams, public repos, simple builds.

### Take-home cleanup checklist

A participant who does the optional hands-on must: revert the workflow to `ubuntu-latest`,
`docker stop` the runner, and confirm it's gone from the Runners list. The registration
tokens from `gh api` are short-lived, but if they minted a PAT for any of this, have them
**revoke it** — a lingering token is a real security smell; push them to complete the cleanup.
