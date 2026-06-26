# Lab 03 — GitHub Actions

**A ~3-hour workshop.** One continuous arc: take the Ignition project you already
know and build a **CI safety net** around it — local linters first, then a GitHub
Actions workflow that makes those checks a required gate on every PR, then a look at
*where* CI runs when GitHub-hosted isn't enough.

> The subject is the same Ignition gateway and Perspective project from Lab 02 (a
> cold-storage "Overview" HMI plus two Jython script libraries). You're not learning
> new application code — you're adding CI around code you already understand. The repo
> tracks only the project files under `projects/`; the gateway generates its own config
> into a Docker volume we never commit. (Lab 04 goes deep on that file layout.)

## Timeboxing

| Time | Part | Mode |
|---|---|---|
| 0:00–0:10 | Intro & setup | talk |
| 0:10–1:10 | **Part 1 — Linters as your safety net** | I-do + you-do |
| 1:10–2:25 | **Part 2 — GitHub Actions: workflows, jobs, required checks** | I-do + you-do |
| 2:25–2:55 | **Part 3 — Self-hosted runners: when, why, how** | demo + discussion |
| 2:55–3:00 | Wrap-up & take-home | talk |

## Setup

You'll need: Docker (Compose V2), Python 3.10+, and a GitHub repo of your own to open
PRs against. Clone, copy the env file, and confirm the gateway boots:

```bash
cp .env.example .env
ops/setup.sh        # boots one Ignition gateway, waits for RUNNING, prints the URL + login
```

Install the linters (macOS shown; Linux/Codespaces use `apt`/release tarballs):

```bash
brew install yamllint shellcheck actionlint
pip install yamllint==1.35.1 ign-lint==0.6.1     # ign-lint needs Python 3.10+
```

Reference reading lives in [`docs/validation-and-linters.md`](../docs/validation-and-linters.md)
and [`docs/self-hosted-runners.md`](../docs/self-hosted-runners.md).

---

## Part 1 — Linters as your safety net (60 min)

**Goal:** run yamllint, shellcheck, actionlint, **ign-lint**, and `ops/validate.sh`
against a real Ignition project; read each tool's output; decide whether to fix,
configure away, or ignore each finding; and tune `.yamllint.yml` to fit the project.

Every linter is a cheap, fast check that catches one class of bug. The point isn't to
run them all — it's to know which one would have caught yesterday's regression.

### Seed the broken state

```bash
ops/seed.sh
```

This plants **6 issues** into your working tree — one per tool, plus a second ign-lint
finding. Hunt them down with the linters. Reset to a clean tree any time with:

```bash
git restore . && rm -f .github/workflows/example.yml
```

### I do (15 min)

The instructor live-demos on the seeded state. For each tool: run it, read the output,
fix one finding.

1. `yamllint -c .yamllint.yml docker-compose.yml` — YAML syntax + style (finds trailing whitespace).
2. `ops/validate.sh` — the gateway-free green/red signal: every `*.json` under `projects/`
   is valid JSON, every `code.py` parses as Python 3. Exit 0 = green, 1 = red. The same
   check the PR uses.
3. `ign-lint --config rule_config.json --files "projects/**/view.json"` — **the flagship
   tool of this part.** Ignition-native static analysis: it parses the Perspective
   `view.json`, walks the component tree, and checks naming conventions, binding poll
   rates, brittle references, and the Python embedded in views — all without a running
   gateway.
4. `actionlint` — GitHub Actions workflow syntax + expression typing (run it on the seeded `example.yml`).
5. `shellcheck ops/*.sh` — catches almost every shell scripting bug ever made.

Spend the most time on **ign-lint** — it's the one that's genuinely Ignition-aware, and
the one most people here have never seen. Open `rule_config.json` and walk the rules:
`NamePatternRule` (components → PascalCase, properties → camelCase, message handlers →
kebab-case, custom methods → snake_case), `PollingIntervalRule` (a floor on binding poll
rates — 1000 ms here), `BadComponentReferenceRule` (flags `.getSibling()` / `.getParent()`
traversal), `PylintScriptRule`, and the rest. The clean `lab-project` passes ign-lint with
**zero** findings — every finding you see is something `ops/seed.sh` broke on purpose.

### You do (35 min)

Fix the remaining planted issues, then make the config your own.

1. Run each of `yamllint`, `shellcheck`, `actionlint`, `ign-lint`, and `ops/validate.sh`
   and capture the findings in `NOTES.local.md` (gitignored). Make a list.
2. Fix every finding. For each, record: *what the tool flagged*, *why your fix is correct*,
   and *what class of production bug it would catch*.
3. Re-run every linter until each is silent and `ops/validate.sh` exits 0.
4. Open `.yamllint.yml`. We disabled `line-length` for the project — **extend the comment**
   explaining *why* (hint: long compose environment lines).
5. Commit. Your end state should be a clean tree: every linter silent, `ops/validate.sh`
   exits 0.

> Stuck on a finding? [`instructor-notes/lab-key.md`](../instructor-notes/lab-key.md) has the
> walkthrough — but spend at least 5 minutes on it yourself first; the diagnostic skill is
> most of the lesson.

### Debrief (10 min)

- Which of these linters would have caught the most recent real bug your team shipped?
- When does linting *hurt* instead of help? (When it flags style as errors; when it's
  slower than the dev loop; when its config drifts from reality.)
- ign-lint is new to most of you: which of its rules map to a mistake you've actually
  shipped in a Perspective project? Which feel like overreach?

---

## Part 2 — GitHub Actions: workflows, jobs, required checks (75 min)

**Goal:** write a workflow from scratch with sensible defaults (PR trigger,
least-privilege permissions, path filters), wire in the Part 1 linters, and make the
whole thing a *required check* no one can merge past.

Start from a clean tree (Part 1 fixes applied, `.yamllint.yml` in place).

### I do (20 min)

The mental model:

```
workflow  ──contains──▶  jobs  ──contains──▶  steps  ──run──▶  actions or shell commands
   │                       │                      │
   │                       │                      └── env, working-directory…
   │                       └── runs-on, needs, strategy, permissions
   └── on (triggers), permissions, concurrency
```

Live-create `.github/workflows/ci.yml`, starting with the gateway-free validator:

```yaml
name: CI
on:
  pull_request:
permissions:
  contents: read
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ops/validate.sh
```

Open a PR, watch it run, read the logs together — each step is its own collapsible block.
Then add a second job that runs the Part 1 linters, including `ign-lint`:

```yaml
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install yamllint==1.35.1 ign-lint==0.6.1
      - run: yamllint -c .yamllint.yml .
      - uses: raven-actions/actionlint@v2
      - run: sudo apt-get update && sudo apt-get install -y --no-install-recommends shellcheck
      - run: shellcheck ops/*.sh
      - run: ign-lint --config rule_config.json --files "projects/**/view.json"
```

`ign-lint` needs Python 3.10+, which is why we pin `setup-python` to `"3.12"`. Discuss as
you go:

- **`permissions: contents: read`** — least privilege; the default `GITHUB_TOKEN` is too broad.
- **`GITHUB_TOKEN`** — auto-provisioned per job, scoped to the repo, expires when the job ends.
- **Secrets vs variables** — secrets are encrypted and masked (`***`) in logs; variables
  are plain text. Live-add an `EXAMPLE_SECRET` and confirm it's masked.

### You do (45 min)

Make the workflow yours.

**1 — Path filters (10 min).** Add a `paths:` filter so the workflow skips docs-only PRs:

```yaml
on:
  pull_request:
    paths:
      - "projects/**"
      - "ops/**"
      - "docker-compose.yml"
      - ".github/workflows/**"
      - ".yamllint.yml"
      - "rule_config.json"
  push:
    branches: [main]
```

Open a PR that touches **only** `README.md` and confirm the workflow is **skipped** (not
just passed).

**2 — Compose validation (5 min).** Add a final step to the lint job:

```yaml
      - run: docker compose config -q
```

This catches Compose-level issues yamllint can't see — undefined services, port-string
typos, malformed environment maps.

**3 — Status badge (5 min).** Add a CI badge to the top of `README.md`:

```markdown
[![CI](https://github.com/<you>/cicd-lab-03-github-actions/actions/workflows/ci.yml/badge.svg)](https://github.com/<you>/cicd-lab-03-github-actions/actions/workflows/ci.yml)
```

**4 — Required check (15 min).** In repo settings, configure branch protection on `main`:
require a PR before merging, and require status checks — select **`lint`** and
**`validate`**. Open a PR that breaks one lint rule (e.g. `ops/seed.sh` then commit one
issue). Confirm GitHub blocks the merge. Fix and re-push.

**5 — Sanity check (10 min).** Commit any remaining changes. Your workflow should match
the shipped [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — see
[`instructor-notes/lab-key.md`](../instructor-notes/lab-key.md) for the reference end state.

### Stretch `[OPTIONAL]`

- **Matrix `ign-lint` over individual views** so each view surfaces as its own check — a
  one-entry matrix today, but the pattern that scales as the HMI grows. (For now the single
  globbed step is plenty; the matrix is about isolating *which* view broke, not speed.)
- **Read, don't implement:** the difference between `on: pull_request` and
  `on: pull_request_target`. The latter runs the base-branch workflow *with secrets*
  against the PR's code — a well-known privilege-escalation footgun. See the
  [GitHub Security Lab post](https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/).

### Debrief (5 min)

- Where does the workflow actually run? (An ephemeral runner spun up per job.)
- What happens when a step fails midway? A whole job? (`continue-on-error`, `needs:`.)
- Required checks are a contract with the *team*, not just a setting — who decides what's blocking?

---

## Part 3 — Self-hosted runners: when, why, and how (30 min)

**Goal:** decide when GitHub-hosted isn't enough, understand the security model, and see a
runner registered and routed end-to-end. (This part is a guided demo + discussion; the
full hands-on is an optional take-home below.)

### When GitHub-hosted is enough — which is most of the time

Your code lints and validates on a standard image; you're not blocked by network or
compliance; you don't need local hardware. Use GitHub-hosted runners and move on.

### When self-hosted is required

1. **Network isolation** — the thing you deploy to is behind a firewall (an on-prem
   Ignition gateway, a PLC network, a private database). GitHub-hosted runners can't reach it.
2. **Compliance / data residency** — builds must run on infrastructure your org controls.
3. **Real hardware** — a physical PLC, a USB device, a specific OS.
4. **Cost at very high volume** — occasionally, rarely for small teams.

### The security model (the part that matters most)

A runner machine has full access to whatever it can reach on its network. Connect a
self-hosted runner to a **public** repo with **fork PRs** enabled and a malicious PR can
execute arbitrary code *on your network* by adding a step to the workflow.

> **Rule:** never connect a self-hosted runner to a public repo with fork PRs. If you must,
> use *ephemeral* runners that self-destruct after each job, and require approval for
> first-time contributors.

The architecture is poll-based: the runner is a lightweight agent that **polls** GitHub for
assigned jobs, runs them, and returns logs. There is no inbound connection from GitHub to
your network — only outbound polling.

### Instructor demo (≈15 min)

The instructor registers an ephemeral Docker-based runner and routes one job to it:

```bash
# 1. Registration token (≤1h lifetime)
export RUNNER_TOKEN="$(gh api -X POST \
  "repos/<user>/<repo>/actions/runners/registration-token" --jq .token)"

# 2. Start an ephemeral runner labelled self-hosted,local-lab03
docker run -d --rm --name lab03-runner \
  -e REPO_URL="https://github.com/<user>/<repo>" \
  -e RUNNER_NAME="lab03-$(whoami)" \
  -e RUNNER_TOKEN="$RUNNER_TOKEN" \
  -e LABELS="self-hosted,local-lab03" \
  -e EPHEMERAL=true \
  -v /var/run/docker.sock:/var/run/docker.sock \
  myoung34/github-runner:latest

docker logs -f lab03-runner          # watch for "Listening for Jobs"
```

Then a one-step workflow targeting it (`runs-on: [self-hosted, local-lab03]`), triggered
with `gh workflow run`, and the job executing live in `docker logs`. Note what's *different*
from GitHub-hosted: the runner has only what you put on it (e.g. no preinstalled
`shellcheck`).

### Discussion (≈15 min)

- Looking at your own work: which of your deploys would *require* a self-hosted runner today?
  Push for specifics — "our gateway is behind the customer's VPN; GitHub-hosted physically
  can't reach it" beats "maybe."
- What guardrails would you put on a production runner? (Ephemeral lifecycle; repo-scope only;
  network-isolated; short-lived tokens over OIDC, not stored secrets; restricted PR triggers.)
- For an Ignition shop, where does the runner sit — on the gateway server, or a separate
  build host? What does each imply about access? (We come back to this in Lab 05.)

### Optional take-home — full hands-on

Register your own runner with a unique label (`solo`), route the `validate` job to it
(`runs-on: [self-hosted, solo]`), confirm it runs locally, then **clean up**: revert the
workflow, `docker stop` the runner, confirm it's offline in *Settings → Actions → Runners*,
and **revoke the PAT**. A lingering runner or token is a real security smell, not a
procedural detail. Full steps are in [`docs/self-hosted-runners.md`](../docs/self-hosted-runners.md)
and the lab key.

---

## Wrap-up & take-home (5 min)

You built a CI safety net for an Ignition project, end to end:

- **Local linters** — yamllint, shellcheck, actionlint, **ign-lint**, and `ops/validate.sh`
  — each catching a class of bug before it ships.
- **A GitHub Actions workflow** that runs them on every PR, with least-privilege permissions,
  path filters, and a status badge.
- **A required check** that turns "please run the linters" into "you cannot merge until they pass."
- **An understanding of self-hosted runners** — when they're worth it, and the security
  weight they carry.

**Take-home (optional):** complete the self-hosted runner hands-on above.

**What's next:** Lab 04 opens up the Ignition file structure itself — `project.json`, view
exports, and how to deploy project files to a gateway properly — building on the CI
foundation you just laid.
