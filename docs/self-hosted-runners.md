# Self-hosted runners — cheat sheet

Reference reading for Part 3 (self-hosted runners). Self-hosted runners solve specific problems; they introduce specific risks. Use them deliberately.

## The architecture in one paragraph

A GitHub Actions runner is a lightweight agent. It registers with GitHub using a token, then polls GitHub for assigned jobs. When a job is assigned, the runner downloads the workflow definition, executes the steps on the host machine, and returns the logs. There is no inbound network connection from GitHub to the runner — only outbound polling. The runner is registered to either a repo, an organization, or an enterprise.

## When you actually need one

GitHub-hosted runners are fine for almost everything. You need self-hosted when one of these is true:

1. **Network isolation.** The thing you need to deploy to is behind a firewall. An on-prem Ignition gateway, a PLC network, a private database, an internal artifact registry — GitHub-hosted runners simply can't reach them.
2. **Compliance / data residency.** Auditors require builds run on infrastructure your organization controls. Common in regulated industries (pharma, finance, defense).
3. **Real hardware access.** Testing against a physical PLC, an OPC-UA server, a specific USB device, a particular OS configuration. GitHub-hosted runners are Linux/macOS/Windows VMs — they don't have your USB-attached serial debugger.
4. **Cost at very high volume.** Sometimes — usually not for small teams. If you're running >10,000 minutes/month and your jobs are CPU-bound, self-hosted *might* be cheaper. Don't optimize for cost prematurely.

If none of these apply, don't reach for self-hosted. The operational cost — maintaining a runner host, keeping the agent up to date, monitoring its disk — outweighs the convenience.

## The security model

A self-hosted runner is a *highly trusted* piece of infrastructure. It has:

- Full filesystem access on its host
- Whatever network access the host has (to your internal network, your secrets, your other build systems…)
- Whatever credentials the host has cached
- The ability to execute arbitrary code from any job assigned to it

**The single most important rule:** never pair a self-hosted runner with a public repo that accepts PRs from forks. A malicious PR can modify `.github/workflows/ci.yml` to exfiltrate secrets, install a backdoor, or pivot to other systems on your network. The runner will dutifully execute it.

**Defenses:**

- Use **ephemeral runners** — destroyed after every job, no persistent state. Limits damage from a compromised job.
- **Scope to private repos** only. Or to specific approved orgs.
- **Restrict who can trigger workflows.** Require approval for PRs from first-time contributors.
- **Network-isolate the runner.** It should be on its own subnet, with only the outbound access it needs.
- **Never give the runner production credentials.** Use short-lived tokens issued per-job via OIDC.

## Lifecycle

1. **Register** — provide a registration token (generated via GitHub UI or API). The runner exchanges this for a long-lived credential and starts polling.
2. **Poll** — the runner reaches out to GitHub every few seconds asking "any jobs for me?"
3. **Execute** — when assigned, run the steps.
4. **Return logs.**
5. **Wait or terminate** — long-lived runners keep polling; ephemeral runners exit and the next job spawns a fresh instance.
6. **De-register** — when you're done with a runner, remove it from GitHub *and* stop the host process.

Lingering offline runners in your settings page is a smell — clean them up.

## Setup options, ranked by friction

### Docker-based ephemeral (lab choice)

```bash
docker run -d --rm \
  --name my-runner \
  -e REPO_URL="https://github.com/user/repo" \
  -e RUNNER_TOKEN="..." \
  -e EPHEMERAL=true \
  myoung34/github-runner:latest
```

One command, one container, auto-cleanup. Perfect for development and labs. Not great for production (no monitoring, no recovery if the container dies).

### Bare-metal install

Download the runner tarball, run `config.sh` to register, run `run.sh` to start polling. Wrap in a systemd unit on Linux or a Windows Service. This is what most production deployments end up looking like. More setup, more reliable.

### Kubernetes via Actions Runner Controller

Run runners as Kubernetes pods. Auto-scales with job demand. Best for high-volume teams. Overkill for almost everyone else.

### Auto-scaling on cloud VMs

Various tooling (philips-labs/terraform-aws-github-runner, etc.) spins up a fresh EC2 instance per job, runs it, terminates. Good middle ground for variable workloads.

## Common gotchas

- **PATH and tools.** Your self-hosted runner doesn't have what `ubuntu-latest` has preinstalled. If your workflow assumes `shellcheck` is on the PATH, you need to install it on the runner host (or in the workflow).
- **Disk fills up.** Long-lived runners accumulate Docker images, build artifacts, npm caches. Add a cleanup step or use ephemeral runners.
- **Hangs.** A job that never returns will tie up the runner indefinitely. Always set timeouts (`timeout-minutes:` at job level).
- **Token rotation.** Registration tokens expire after one hour. The *runner credential* (created from the registration token) is long-lived but tied to the runner's GUID. Re-registering creates a new runner; the old one lingers as "Offline."

## Ignition-specific notes

For an Ignition CI/CD pipeline:

- **Where the runner sits.** Usually on a build host that has network access to the target gateway(s), not on the gateway itself. Keeps build and runtime concerns separated.
- **What it deploys.** File-based deploys: rsync or scp the project into `<gateway>/data/projects/<project>/`. Then poke the gateway's REST API to scan for project changes.
- **Permissions.** The runner needs to write to gateway data directories. Use a dedicated service account, not your personal credentials.

We'll build a real Ignition deploy job (against a sandbox gateway) in Lab 05.

## Further reading

- [GitHub's official docs on self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Security guide for self-hosted runners](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#hardening-for-self-hosted-runners)
- [`myoung34/docker-github-actions-runner`](https://github.com/myoung34/docker-github-actions-runner) — the image we use in Part 3
- [Actions Runner Controller](https://github.com/actions/actions-runner-controller) — Kubernetes-native runner management
