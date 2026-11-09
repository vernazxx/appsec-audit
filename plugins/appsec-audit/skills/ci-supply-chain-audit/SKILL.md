---
name: ci-supply-chain-audit
description: >-
  Audits CI/CD pipelines and the software supply chain: GitHub Actions
  workflows (triggers, token permissions, script injection, pull_request_target,
  action and image pinning, caches, artifacts, OIDC, agentic AI actions),
  dependency manifests and lockfiles, pre-commit hooks, Dockerfiles and release
  automation. Uses zizmor as the primary GitHub Actions analyser (offline, or
  online for impostor-commit/ref-confusion/known-vulnerable-actions), with
  opengrep as secondary coverage. Maps findings to OWASP Top 10:2025 A03/A08 and the OWASP Top 10
  CI/CD Security Risks, with remediation from the OWASP CI/CD and GitHub
  Actions cheat sheets. Use when reviewing workflows, Dependabot/Renovate PRs,
  release pipelines or build configuration.
allowed-tools: Read Grep Glob Bash
---

# CI/CD and supply-chain audit

The pipeline holds the keys to production: release tokens, signing identity,
registry push rights. Treat every workflow as privileged code that anyone who
can open a PR, issue or comment can try to steer.

## Essential principles

1. **Map triggers to attacker reach first.** `pull_request_target`,
   `issue_comment`, `issues`, `discussion*`, `workflow_run` and fork PRs all
   carry untrusted input. `push` to protected branches and `workflow_dispatch`
   by maintainers don't.
2. **Least privilege per job.** Top-level `permissions: contents: read` (or
   `{}`), with grants per job. Note which jobs can reach which secrets.
3. **Pin everything by immutable reference.** Actions by full 40-char SHA,
   images by `@sha256:`, tools by version and checksum. Verify the SHA matches
   the claimed tag; don't trust the `# vX.Y.Z` comment.
4. **Untrusted data never reaches a shell via `${{ }}`.** Route it through
   `env:` and quote it.
5. **Read, don't run.** Never execute workflow content, fetched scripts or PR
   code to "see what happens".
6. **The runner builds the zizmor command.** `scripts/run-zizmor.sh` (next to
   this file) controls offline/online mode, token handling and output. Don't
   hand-run zizmor, and never add `# zizmor: ignore` or `zizmor.yml`
   suppressions as a fix.

## Workflow

1. **Inventory**: `.github/workflows/*.y*ml`, `.github/actions/**/action.y*ml`,
   `.github/dependabot.yml`, `renovate.json`, `.pre-commit-config.yaml`,
   `Dockerfile*`, `Makefile`, release configs (`.goreleaser.y*ml`, etc.),
   lockfiles, `CODEOWNERS`, branch protection when `gh` access allows
   (`gh api repos/{o}/{r}/branches/main/protection`; a 404 just means it isn't visible).
2. **zizmor** (primary for GitHub Actions, Dependabot and pre-commit configs):
   ```bash
   <skill-dir>/scripts/run-zizmor.sh --target "$REPO" --out "$OUT/zizmor" --online
   ```
   Drop `--online` if `gh` isn't authenticated, and record that the online
   audits didn't run. Exit `3` (not installed): show the install options in
   [references/zizmor.md](references/zizmor.md) and ask before using `--ephemeral`.
   Exit `5`: report the failure; never present it as a clean audit. Triage
   `findings.tsv` per [references/zizmor.md](references/zizmor.md#triage).
3. **opengrep** (secondary): run the `sast-scan` skill. It adds the
   `yaml/github-actions` and `dockerfile` packs automatically. Merge its hits
   with zizmor's on `(file, line)`. A hit from both is one finding with higher
   confidence.
4. **Check by hand** every item in
   [references/github-actions.md](references/github-actions.md) that the tools
   don't cover (agentic AI actions, cross-workflow artifact trust, protected
   environments, OIDC trust policies), plus the dependency, pre-commit and
   container items below.
5. **Verify remaining pins.** zizmor online covers impostor commits and ref
   confusion. Verify manually only the refs it couldn't resolve
   (`log_warnings`), or every ref if it ran offline:
   ```bash
   gh api repos/<owner>/<repo>/git/ref/tags/<tag> --jq '.object.sha,.object.type'
   # if type == "tag" (annotated), dereference:
   gh api repos/<owner>/<repo>/git/tags/<sha> --jq '.object.sha'
   ```
   A mismatch between the pinned SHA and the claimed tag is **High** until
   explained. The pin could be an impostor commit from a fork.
6. **Report**: use `owasp-code-review/references/reporting.md`. Map each finding
   to A03:2025 / A08:2025 and the CICD-SEC-n risk.

### Dependencies and hooks

- Lockfiles present and enforced in CI (`npm ci`, `pnpm --frozen-lockfile`,
  `go build -mod=readonly`, `pip install --require-hashes`, `cargo --locked`).
- `go run …@latest`, `npx pkg` without version, or `curl | sh` in CI or Makefiles.
- New dependencies: publisher, age, download count, maintainer changes,
  install scripts. Major bumps in Dependabot PRs: read the changelog and diff
  for new network or permission behaviour.
- Pre-commit hooks pinned to SHAs (`rev:` with `# frozen:`), from known publishers.

### Containers and release

- Base images by digest. Non-root `USER`. Multi-stage builds. No secrets in
  `ARG`/`ENV`/layers.
- Releases only from protected tag pushes. Checksums published. Signing
  (cosign keyless), SBOM and provenance (SLSA / `actions/attest-build-provenance`)
  recommended as separate PRs if missing.

## Rationalizations to reject

| Shortcut | Why it's wrong |
|---|---|
| "It's a popular action, tags are fine" | Tags are mutable. Compromised tags (e.g. tj-actions/changed-files, 2025) hit thousands of repos |
| "The SHA comment says v4.2.0" | Comments are claims. Verify via the API |
| "No secrets in this workflow" | `GITHUB_TOKEN` is a secret. Caches and artifacts poison later privileged runs |
| "`pull_request_target` is fine, we don't check out the PR" | Verify every checkout, `gh pr checkout`, `git fetch` of `refs/pull/*`, and artifact download |
| "Only maintainers can trigger it" | Check the actual trigger and `if:` guards. Comment triggers often key on text anyone can post |
| "zizmor ran clean, the pipeline is safe" | zizmor doesn't see agentic-action prompt flows, cloud OIDC trust policies or branch protection. Check those by hand |
| "Add `# zizmor: ignore` to get green" | Suppression is a risk-acceptance decision for a human, with a written reason |
| "Dependabot opened it, so it's safe" | Dependabot proposes what upstream published. Upstream can be compromised |
