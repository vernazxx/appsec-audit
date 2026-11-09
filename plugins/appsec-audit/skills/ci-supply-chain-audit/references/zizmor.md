# zizmor

[zizmor](https://github.com/zizmorcore/zizmor) ([docs](https://docs.zizmor.sh)) is
a static analyser for GitHub Actions. It's the primary tool for this skill. It
audits workflows, composite actions, `dependabot.yml` and `.pre-commit-config.yaml`
with data-flow-aware checks that pattern rules can't match (template injection
through contexts, `pull_request_target` reachability, impostor commits).

## Install

Prefer the distro or PyPI package over release binaries, which upstream calls
best-effort:

```bash
pacman -S zizmor                    # Arch (community-maintained)
uv tool install zizmor==1.31.1      # PyPI, version-pinned
brew install zizmor
cargo install --locked zizmor       # --locked is strongly recommended upstream
```

`run-zizmor.sh --ephemeral` runs the version pinned in
`scripts/zizmor-requirements.txt` without installing it: pip downloads the
wheel with `--require-hashes` against that lock, the script runs it from a temp
dir and deletes it afterwards. This is the same mechanism `zizmor-action` uses.
Ask the user before using it, because it downloads from PyPI. It needs `python3`
with `pip`.

## Running

```bash
<skill-dir>/scripts/run-zizmor.sh --target "$REPO" --out "$OUT" [--online] [--persona auditor]
```

| Flag | Default | Meaning |
|---|---|---|
| `--persona` | `auditor` | `regular` = high-signal only. `pedantic` = adds code smells. `auditor` = everything, including likely FPs, for manual triage |
| `--online` | off | Uses `gh auth token` (exported in a subshell, never on argv) to enable the GitHub-API audits |
| `--ephemeral` | off | Hash-verified pinned zizmor if none is installed |

Outputs: `zizmor.json`, `zizmor.sarif`, `findings.tsv` (severity, confidence,
audit, file:line, annotation, docs URL), `scan.json`, `zizmor.log`.

Exit codes: `0` completed (or `status: no-inputs`), `2` usage, `3` zizmor
unavailable, `5` zizmor failed. On `5`, report the failure and stop.

### Offline vs online

Offline (default) makes no network calls. **Online is required** for:
`impostor-commit`, `ref-confusion`, `known-vulnerable-actions`,
`ref-version-mismatch`, `stale-action-refs`, `archived-uses` and similar
audits that resolve refs against GitHub. Use `--online` whenever `gh` is
authenticated. It replaces most of the manual pin-verification step, which is
then only needed for refs zizmor couldn't resolve.

If `scan.json` has `log_warnings > 0`, read `zizmor.log`. Lines like "fast path
impostor check failed … request error" mean an online check fell back to a slower
path or didn't complete for that repo. List those refs as "pin unverified" unless
you verify them manually with `gh api`.

## Triage

The auditor persona over-reports on purpose. For each row:

- **Severity/confidence are zizmor's**, not yours. Re-rate with
  `owasp-code-review/references/reporting.md` given the trigger exposure,
  token permissions and secrets reachable from that job.
- Group per audit + root cause. Six `artipacked` hits on six checkouts are one
  finding with six locations.
- Common auditor-persona noise: `anonymous-definition`,
  `undocumented-permissions` and `concurrency-limits` on non-deploy workflows.
  Report them as Info or drop them as hygiene, with a line in the dismissed list.
- `template-injection`: confirm the expression is attacker-controllable
  (`github.event.*` text fields, `head_ref`, `inputs.*` on externally
  triggerable events). Constants and `github.sha` are false positives.
- `cache-poisoning`: high impact only when a release or publish job restores a
  cache that untrusted-trigger workflows can write.
- `excessive-permissions`: check whether the scope is genuinely needed and
  whether it can move from workflow level to the single job that needs it.

Suppressions: zizmor honours `# zizmor: ignore[<audit>]` comments and a
`zizmor.yml` config. An existing suppression is a claim to verify, not a reason
to skip. **Never add suppressions as a "fix".**

## Audit → checklist mapping

| zizmor audit | Checklist # (github-actions.md) |
|---|---|
| `excessive-permissions`, `undocumented-permissions` | 1, 2 |
| `dangerous-triggers`, `bot-conditions`, `unsound-condition`, `unsound-contains` | 3, 15 |
| `template-injection` | 4 |
| `unpinned-uses`, `stale-action-refs`, `ref-version-mismatch` | 5 |
| `impostor-commit`, `ref-confusion` | 6 |
| `unpinned-images`, `hardcoded-container-credentials` | 7 |
| `secrets-inherit`, `overprovisioned-secrets`, `secrets-outside-env`, `unredacted-secrets` | 8 |
| `artipacked` | 9 |
| `cache-poisoning` | 10 |
| `self-hosted-runner` | 12 |
| `use-trusted-publishing` | 13 |
| `concurrency-limits` | 16 |
| `insecure-commands`, `github-env` | 18 |
| `known-vulnerable-actions`, `archived-uses`, `typosquat-uses`, `forbidden-uses`, `obfuscation` | 5, 20 |
| `adhoc-packages`, `unpinned-tools`, `insecure-url-scheme` | 17 |
| `dependabot-cooldown`, `dependabot-execution` | 20 |

zizmor has no audit for item 19 (agentic AI actions), 11 (artifact trust
between workflows) or 14 (protected environments). Check those by hand.

## Recommending zizmor in CI

If the repo doesn't run zizmor, recommend it as a separate PR via
`zizmorcore/zizmor-action` pinned by SHA (verify the tag). Set `version:` to an
exact zizmor release: the action defaults to `latest`. It installs that version
from a hash-pinned lock in its own tree, so the action SHA plus `version:` fix
exactly what runs. Dependabot bumps the action SHA but not `version:`, so call
out that it needs deliberate bumps.

Pick the output mode by what the repo has:

| Repo | Settings | Permissions |
|---|---|---|
| Code scanning available (public, or GitHub Advanced Security) | default `advanced-security: true` (SARIF to the Security tab) | `security-events: write` on that job only |
| No code scanning (private without GHAS) | `advanced-security: false`, `annotations: true`: findings become PR annotations and fail the job | none beyond `contents: read` |

Check out with `persist-credentials: false`. Online audits use the job's
read-only `GITHUB_TOKEN`; keep them on. Respect the repo's release cooldown when
picking versions (e.g. Dependabot `cooldown.default-days`).

Or recommend the pre-commit hook `zizmorcore/zizmor-pre-commit` pinned with
`rev: <sha> # frozen: vX.Y.Z`.
