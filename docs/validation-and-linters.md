# Validation and linters — cheat sheet

Reference reading for Part 1 (linters). The point isn't to use every linter; the point is to know which one catches which class of bug, and to install only the ones that earn their place. This lab ships an Ignition gateway running a Perspective HMI project, so the toolset is built around the files we actually track: YAML, workflows, shell scripts, and Perspective `view.json` resources.

## The tools we install

| Tool | What it catches | Speed | Where it runs |
|---|---|---|---|
| **yamllint** | YAML syntax + style issues (`docker-compose.yml`, workflows, `.yamllint.yml`) | ms | local + CI |
| **actionlint** | GitHub Actions workflow correctness (syntax + expression typing) | ms | local + CI |
| **shellcheck** | Bash scripting bugs in `scripts/*.sh` (the canonical ones, and many subtle ones) | ms | local + CI |
| **ign-lint** | Ignition-native static analysis of Perspective `view.json` files and embedded scripts | seconds | local + CI |

Plus two validators that aren't really linters:

| Tool | What it catches |
|---|---|
| **`scripts/validate.sh`** | Gateway-free project validator: every `*.json` under `projects/` is valid JSON, every `code.py` parses as Python 3. Exits 0/1 — the green/red signal for your PR. |
| **`docker compose config -q`** | Compose schema validation. Catches "service not defined", port-string typos, malformed environment maps. |

## A mental model

Linters fall into three groups:

**1. Syntax linters.** They verify the file *parses correctly* under the tool's grammar. `yamllint`, `docker compose config`, `actionlint`, and `scripts/validate.sh` (JSON + Python parse-checks). Cheap, fast, hard to argue with.

**2. Best-practice linters.** They verify the file follows known-good *patterns*. `shellcheck` flagging an unquoted `$VAR`, or `ign-lint` flagging a Perspective component reached via brittle `.getParent().getChild(...)` traversal, isn't a syntax error — it's a "this will work today but break the moment someone renames or reorders something" warning. These are the most valuable category; they encode operational wisdom.

**3. Style linters.** They verify the file matches an opinionated *aesthetic*. Some `yamllint` rules (line length, trailing commas) and `ign-lint`'s naming conventions (PascalCase components, camelCase properties) live here. These are useful in a team context — consistency reduces cognitive load — but they're also the most fiddly. You're allowed to tune or disable rules you don't like, *as long as the team agrees* (and the config is checked in so the agreement is enforced).

When choosing what to enable, start with #1 and #2; treat #3 as opt-in.

## ign-lint — the Ignition-native linter

The other tools are generic. `ign-lint` is the one that actually understands Ignition. It statically analyzes Perspective `view.json` files — and the Python scripts embedded inside them — **without a running gateway**. That makes it perfect for CI: no Docker, no gateway boot, no licensing dance, just a fast pass over the project files on disk.

- **PyPI package:** `ign-lint` (v0.6.1)
- **CLI:** `ign-lint`
- **Install:** `pip install ign-lint==0.6.1` (needs Python 3.10+)
- **Run:** `ign-lint --config rule_config.json --files "projects/**/view.json"`
- **Repo:** <https://github.com/bw-design-group/ignition-lint>
- **Docs:** <https://bw-design-group.github.io/ignition-lint>
- **Maintainer:** [BW Design Group](https://github.com/bw-design-group)

> **A note on maturity.** `ign-lint` is pre-1.0 (v0.6.1) and maintained by a single systems
> integrator. That's not a knock — it's genuinely the best Ignition-native linter available,
> and the reason this lab leans on it. But pin the version (the rule schema and CLI can still
> change between releases), and treat what you're learning as the durable part: the *pattern*
> of an Ignition-aware linter running as a required CI check. The specific tool may evolve or
> be replaced; the practice won't.

It's configured by a repo-root `rule_config.json`, which is tuned so this lab's clean `lab-project` passes with zero findings. Built-in rules worth knowing:

- **NamePatternRule** — enforces naming conventions per node type: components → `PascalCase`, properties → `camelCase`, message handlers → `kebab-case`, custom methods → `snake_case`. Severity is set per node type (in this lab, component and custom-method violations are `error`; property and message-handler violations are `warning`).
- **PollingIntervalRule** — flags `now()` / expression polling faster than a configured minimum. In this lab the minimum is **1000 ms**; anything faster is a finding (a 250 ms poll on a Perspective binding is a real performance footgun at scale).
- **PylintScriptRule** — runs pylint over the Python scripts embedded in views, mapping pylint categories to error/warning severities.
- **BadComponentReferenceRule** — flags brittle traversal like `.getSibling()`, `.getParent()`, and other relative walking that breaks when the component tree is edited.
- **ComponentReferenceValidationRule** — verifies that relative references actually resolve to a real component (validates expressions, property bindings, and scripts).
- **UnusedCustomPropertiesRule** — flags custom properties that nothing reads.
- **ExcessiveContextDataRule** — flags oversized context data (large arrays, deep nesting, too many sibling properties / data points).

This is the answer to the question the old version of this doc couldn't answer: yes, there *is* a public Ignition validator for Perspective views, and it runs gateway-free in CI.

## scripts/validate.sh — the gateway-free project validator

`ign-lint` covers Perspective views deeply; `scripts/validate.sh` is the broad, dependency-light backstop. It walks `projects/` and checks two things:

1. every `*.json` resource is valid JSON, and
2. every `code.py` parses as Python 3.

It needs nothing but `python3` — no gateway, no Docker — runs in about a second, and exits `0` when everything is valid, `1` otherwise. That exit code is the **green/red signal for your pull request**; it mirrors the "Validation passes locally" checkbox in the PR template. (Note: the gateway runs Jython 2.7, so this is a fast Python-3 syntax sanity check, not a Jython validator — write Python-3-parseable syntax and you're fine.)

## Common findings and what they mean

### yamllint

- `line too long` — your line exceeds the configured limit. Often a false positive for compose env strings; tune `line-length` in `.yamllint.yml`.
- `trailing spaces` — exactly what it says. Fix by stripping the whitespace.
- `truthy value should be true/false` — YAML's `yes`/`no`/`on`/`off` boolean shorthand; surprisingly often unintentional.

### shellcheck

- `SC2086: Double quote to prevent globbing and word splitting` — the canonical shellcheck finding. `$VAR` should almost always be `"$VAR"` unless you specifically want word-splitting.
- `SC2148: Missing shebang` — add `#!/usr/bin/env bash` at the top.
- `SC2034: VAR appears unused` — exactly what it says.
- `SC2155: Declare and assign separately` — `local x=$(cmd)` masks `cmd`'s exit status. Split into two lines.

### actionlint

- `unknown action` — typo in the action name, or you forgot to pin a version.
- `expression type mismatch` — `${{ steps.foo.outputs.value }}` referenced before `foo` runs; or wrong type in arithmetic.
- `outdated runner image / action` — `ubuntu-18.04` is gone; use `ubuntu-latest` or a specific current version. Likewise pin actions to a current release, not an abandoned tag.

### ign-lint

- **Non-PascalCase component name** — a component named `myButton` or `temp_gauge` instead of `TemperatureGauge`. `NamePatternRule`, severity `error`.
- **Sub-minimum polling interval** — a binding polling faster than 1000 ms. `PollingIntervalRule`. Bump the interval, or rethink whether you need polling at all (a tag change-driven binding is usually better).
- **Brittle component reference** — a script reaching another component via `.getParent().getSibling(...)`. `BadComponentReferenceRule` / `ComponentReferenceValidationRule`. Use a stable reference (a custom property, a message handler, or a session/page-scoped path) instead.

## When linting helps and when it doesn't

**Helps when:**

- It catches the same bug every dev would otherwise hit
- It's fast enough to run on save (or pre-commit)
- The config matches your team's reality (not a copy-pasted default)

**Hurts when:**

- It flags style preferences as errors, blocking PRs
- It's slower than the dev cycle (a 90s lint on every save is a productivity drain)
- The config drifts from reality (new rules added upstream that no one in your team agrees with)

The cure for the second category is usually local config you check in — `.yamllint.yml`, `rule_config.json` — not "disable the linter entirely."

## Further reading

- [yamllint docs](https://yamllint.readthedocs.io/) — full rule reference
- [shellcheck wiki](https://www.shellcheck.net/wiki/) — the canonical guide; every error code is a learnable lesson
- [actionlint docs](https://github.com/rhysd/actionlint/blob/main/docs/checks.md) — what it checks and how
- [ign-lint docs](https://bw-design-group.github.io/ignition-lint) — rule reference and configuration
- [ign-lint repo](https://github.com/bw-design-group/ignition-lint) — source, issues, and release notes
