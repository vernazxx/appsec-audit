# GitHub Actions checklist

Items 1–10, 12, 13, 15–18 and 20 are largely automated by zizmor (see the
mapping in [zizmor.md](zizmor.md)). Items 11, 14 and 19 need manual review.
Every item still needs a pass/fail/N/A verdict in the report.

Sources: OWASP GitHub_Actions_Security and CI_CD_Security cheat sheets, the OWASP Top 10
CI/CD Security Risks (https://owasp.org/www-project-top-10-ci-cd-security-risks/),
and GitHub's "Security hardening for GitHub Actions" docs.

| # | Check | Report when | Severity hint | Risk |
|---|---|---|---|---|
| 1 | Top-level `permissions` | Missing (inherits repo default, possibly write-all) or broader than `contents: read` | Medium (High if untrusted trigger) | CICD-SEC-5 |
| 2 | Job-level grants | `contents: write`, `packages: write`, `id-token: write`, `actions: write` on jobs that don't need them, or on jobs that process untrusted input | Medium–High | CICD-SEC-5 |
| 3 | `pull_request_target` / `workflow_run` | Checks out or runs PR head code (`ref: ${{ github.event.pull_request.head.sha }}`, `refs/pull/*/merge`), or downloads artifacts from the triggering run and executes or trusts them | **Critical** with secrets/write token | CICD-SEC-4 |
| 4 | Script injection | `${{ github.event.* }}` (title, body, head_ref, comment, commit message, label name, `inputs.*` on public dispatch) interpolated in `run:`, `script:` (github-script) or composite `run:` | High | CICD-SEC-4 |
| 5 | Action pinning | `uses: owner/repo@vN`/`@main`/short SHA. Docker `uses: docker://img:tag` | Medium (High if job has secrets) | CICD-SEC-3, -8 |
| 6 | Pin authenticity | SHA doesn't match the claimed tag, or SHA isn't reachable from the upstream repo (impostor commit via fork network) | High | CICD-SEC-3 |
| 7 | Container images | `container:`/`services:`/`docker run` without `@sha256:` | Medium | CICD-SEC-3 |
| 8 | `GITHUB_TOKEN` / secrets handling | Secrets echoed, written to files uploaded as artifacts, passed to third-party actions that don't need them, `secrets: inherit` to reusable workflows | High | CICD-SEC-6 |
| 9 | `actions/checkout` credentials | `persist-credentials` not `false` in jobs that later run untrusted code or upload the workspace | Medium | CICD-SEC-6 |
| 10 | Caches | Untrusted-trigger workflows write caches later restored by privileged/release workflows (cache poisoning) | High | CICD-SEC-9 |
| 11 | Artifacts | Release jobs consume artifacts produced by untrusted runs. Artifacts include `.git`/credentials | High | CICD-SEC-9 |
| 12 | Self-hosted runners | Used by public-repo PR workflows. Non-ephemeral | High | CICD-SEC-7 |
| 13 | OIDC | `id-token: write` with cloud trust policies not scoped to repo + ref/environment (`sub` wildcards) | High | CICD-SEC-2 |
| 14 | Environments / approvals | Deploy or release jobs without a protected `environment:` | Medium | CICD-SEC-1 |
| 15 | Triggers | Release on branch push or `workflow_dispatch` instead of signed or protected tags. `if:` guards on actor names that bots/forks can spoof | Medium | CICD-SEC-1 |
| 16 | `concurrency` | Release/deploy without concurrency control (racing deploys) | Low | n/a |
| 17 | Remote scripts | `curl … \| bash`, `go run …@latest`, `npx` unpinned, `pip install` without hashes inside `run:` | Medium–High | CICD-SEC-3 |
| 18 | `GITHUB_ENV` / `GITHUB_OUTPUT` writes | Untrusted data written to `$GITHUB_ENV` (can set `LD_PRELOAD`, `NODE_OPTIONS`) or to multi-line outputs without random delimiters | High | CICD-SEC-4 |
| 19 | Agentic AI actions | `anthropics/claude-code-action`, `openai/codex-action`, `google-github-actions/run-gemini-cli`, `actions/ai-inference` fed attacker-controlled text (directly or via `env:`), with wildcard user allowlists, `Bash(*)`/`danger-full-access`, or whose output is `eval`'d | High–Critical | CICD-SEC-4 |
| 20 | Dependabot / Renovate | Not configured for `github-actions` ecosystem. Auto-merge without review on majors | Low–Medium | CICD-SEC-3 |

Item 19 has no zizmor audit. For deep agentic-action analysis (env-var intermediaries, CLI data fetch,
sandbox configs), Trail of Bits' `agentic-actions-auditor` plugin goes further
and is a good companion.

## Safe patterns to recommend

```yaml
permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<40-char-sha> # vX.Y.Z (verified)
        with:
          persist-credentials: false
      - name: Use PR title safely
        env:
          TITLE: ${{ github.event.pull_request.title }}
        run: printf '%s\n' "$TITLE"
```

```yaml
# Release: tag-triggered, scoped write, protected environment
on:
  push:
    tags: ['v*']
jobs:
  release:
    environment: release
    permissions:
      contents: write
      id-token: write      # only if signing/attesting
      attestations: write  # only if attesting
```
