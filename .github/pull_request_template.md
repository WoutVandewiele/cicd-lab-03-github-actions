<!--
Mustry Academy — PR template
Keep it short; the goal is to make the reviewer's job easy.
-->

## What

<!-- One or two sentences describing what this change does. -->

## Why

<!-- Why are we making this change now? Link any related issue or discussion. -->

## How to test

<!-- Specific commands or steps the reviewer can run. -->

## Checklist

- [ ] Validation passes locally (`scripts/validate.sh`)
- [ ] `ign-lint` is clean (`ign-lint --config rule_config.json --files "projects/**/view.json"`) — for view changes
- [ ] Gateway still starts cleanly (`scripts/setup.sh` → gateway reaches RUNNING) — for project changes
- [ ] No secrets committed
- [ ] Changes are scoped to one logical thing
