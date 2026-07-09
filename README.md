# Lab 03 — GitHub Actions

Day 2 of the [CI/CD for Ignition Masterclass](https://github.com/mustry-academy/cicd-masterclass) — a single hands-on workshop.

> Build a CI safety net around a real Ignition project: run linters that catch problems before they ship, write GitHub Actions workflows from scratch, and understand when to reach for self-hosted runners.

This is the third lab in the course. The subject is the same **Ignition project** you
worked on in [Lab 02](https://github.com/mustry-academy/cicd-lab-02-branching-and-prs) — a
Perspective HMI screen (the Oatmakers Site 04 oat-line overview, the client from
Lab 01) and a couple of Python script
libraries, running on a local gateway you spin up yourself. Lab 02 had you edit those
project files and open PRs **by hand**; this lab makes the checks **automatic**: the
validation you ran manually becomes a required status check no one can merge past.

You don't need deep Ignition experience. The gateway's *administrative* complexity (config,
modules, databases, deploys) is deliberately **abstracted away** — the repo tracks only the
**project files**, and the gateway generates its own config on boot (into a Docker volume we
never commit). How those project files are structured, and how to deploy them properly,
is the subject of [Lab 04](https://github.com/mustry-academy/cicd-lab-04-ignition-file-based-deploy).

## Prerequisites

- Completed [Lab 02](https://github.com/mustry-academy/cicd-lab-02-branching-and-prs)
- Pass [`cicd-preflight`](https://github.com/mustry-academy/cicd-preflight)
- Docker (with the Compose V2 plugin) — ~1.5 GB RAM is plenty for the single gateway
- Python 3.10+ (for the linters: `ign-lint`, `yamllint`)
- The [GitHub CLI](https://cli.github.com/) (`gh`), authenticated (`gh auth status`) — Part 3's
  runner demo mints its short-lived registration token through it; no personal access token needed.

## Quick start

```bash
gh repo clone mustry-academy/cicd-lab-03-github-actions
cd cicd-lab-03-github-actions
cp .env.example .env
scripts/setup.sh        # boots one Ignition gateway, waits for RUNNING, prints the URL + login
# open http://localhost:8088  → log in with the .env credentials
```

Before opening any PR, run the same checks CI runs — both are gateway-free and finish in
seconds:

```bash
scripts/validate.sh                                          # every project file: valid JSON / parseable Python
python3 -m venv .venv && source .venv/bin/activate           # bare pip fails on Homebrew/Ubuntu-24.04 Python (PEP 668)
pip install ign-lint==0.6.1
ign-lint --config rule_config.json --files "projects/**/view.json"   # Ignition-native linting of the Perspective views
```

The other linters Part 1 introduces (install separately — see [`exercises/lab.md`](./exercises/lab.md)):

```bash
source .venv/bin/activate           # the venv from the block above (no-op if still active)
pip install yamllint==1.35.1
yamllint -c .yamllint.yml .
# actionlint, shellcheck install separately — see exercises/lab.md
```

Stop the gateway when you're done:

```bash
scripts/teardown.sh             # stop (keeps the gateway's data volume)
scripts/teardown.sh --volumes   # stop and wipe gateway state for a fresh start
```

## Lab structure

The whole lab is one continuous workshop in [`exercises/lab.md`](./exercises/lab.md):

| Part | Topic |
|---|---|
| 1 | Linters as your safety net (yamllint, shellcheck, actionlint, **ign-lint**, `validate.sh`) |
| 2 | GitHub Actions: workflows, jobs, required checks |
| 3 | Self-hosted runners — a look ahead (short demo) |

Part 1 starts from a deliberately-broken state seeded by [`scripts/seed.sh`](./scripts/seed.sh); the
answer key is in [`instructor-notes/lab-key.md`](./instructor-notes/lab-key.md).

## Repo layout

```
cicd-lab-03-github-actions/
├── README.md
├── docker-compose.yml                 ← one Ignition gateway (named volume + bind-mounted projects/)
├── .env.example                       ← copy to .env before running
├── .gitattributes                     ← LF normalization so Ignition's JSON resources stay clean
├── .yamllint.yml                      ← yamllint config (tuned in Part 1)
├── .pre-commit-config.yaml            ← Part 1 stretch target
├── rule_config.json                   ← ign-lint rule configuration
├── .github/
│   ├── workflows/
│   │   └── ci.yml                     ← the workflow we build in Part 2
│   └── pull_request_template.md
├── scripts/
│   ├── setup.sh                       ← boot the gateway and wait for RUNNING
│   ├── scan.sh                        ← push project-file edits to the running gateway
│   ├── teardown.sh                    ← stop the gateway (--volumes to wipe state)
│   ├── seed.sh                        ← plant Part 1's deliberately-broken state
│   └── validate.sh                    ← the PR green/red check (valid JSON + parseable Python)
├── projects/                          ← the Ignition project (bind-mounted into the gateway)
│   └── lab-project/
│       ├── project.json
│       ├── com.inductiveautomation.perspective/   ← the Perspective HMI dashboard + page config
│       └── ignition/script-python/lab/            ← Python scripts (display + util helpers)
├── exercises/
│   └── lab.md                         ← the workshop (Parts 1–3)
├── docs/                              ← reference reading
└── instructor-notes/
    └── lab-key.md                     ← answer key (read after solo work)
```

## The Compose stack

A single Ignition 8.3 gateway. Two things to understand about how it's wired:

- **The gateway's own config and runtime state live in a named volume** (`ignition-data`) that the gateway generates itself on first boot. It never lands in the repo — which is exactly why you never see or touch gateway config in this lab. (That's Lab 04's subject.)
- **Only `./projects` is bind-mounted** from the repo into the gateway. So the project files you (and CI) validate *are* the project files the gateway runs.

```yaml
services:
  ignition:
    image: inductiveautomation/ignition:8.3.6
    ports: ["8088:8088"]
    volumes:
      - ignition-data:/usr/local/bin/ignition/data        # gateway-owned, self-generated, not in git
      - ./projects:/usr/local/bin/ignition/data/projects   # the one thing you edit

volumes:
  ignition-data:
```

> The gateway regenerates a `.resources/` blob store and other operational files inside `projects/` as it runs. Those are gateway-owned churn and are gitignored — if you ever see them in `git status`, your ignore rules are off.

> **CI is built from scratch here.** Lab 02 deliberately shipped no CI — `scripts/validate.sh` was something *you* remembered to run. This lab adds a `.github/workflows/ci.yml` that you build through the workshop, turning that validation (plus `ign-lint`) into a check every PR must pass. We do **not** call any reusable workflows — you see what's inside before you call it.

## Licence

Apache 2.0 — see [`LICENSE`](./LICENSE).

Do i need to add extra stuff to let it work?
Extra changes