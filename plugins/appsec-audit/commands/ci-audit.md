---
description: "Audit GitHub Actions, Dependabot, pre-commit and release automation with zizmor (primary) and opengrep (secondary), plus a manual OWASP CI/CD and GitHub Actions cheat-sheet checklist and pinned-SHA verification."
argument-hint: "[repo path] [--offline] [--persona regular|pedantic|auditor]"
allowed-tools: Bash Read Grep Glob AskUserQuestion
---

# CI/CD and supply-chain audit

Use the `appsec-audit:ci-supply-chain-audit` skill on the path in `$ARGUMENTS`
(default: repo root).

1. **zizmor first.** Output dir `${TMPDIR:-/tmp}/appsec-audit/<repo>-<UTC timestamp>/zizmor`:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/skills/ci-supply-chain-audit/scripts/run-zizmor.sh" \
     --target <abs repo> --out <out> [--online] [--persona <p>]
   ```
   - Pass `--online` unless `--offline` was given or `gh auth status` fails.
     If you can't go online, say the impostor-commit, ref-confusion and
     known-vulnerable-actions audits didn't run.
   - Exit `3` (zizmor missing): ask with AskUserQuestion whether to run it
     ephemerally via `--ephemeral` (downloads the hash-pinned version from PyPI) or stop
     and install it (see the skill's `references/zizmor.md`).
   - Exit `5`: report the failure verbatim. Don't substitute a manual-only
     audit and call it complete.
2. **opengrep second** via the `sast-scan` skill's `run-scan.sh` with
   `--packs "yaml/github-actions dockerfile generic/secrets"`.
3. **Manual checklist** and pin verification for refs zizmor couldn't resolve.
4. **Read-only.** Don't modify workflows, add suppressions, open PRs or trigger
   workflow runs.
5. **Report** in the `owasp-code-review` reporting format. Map each finding to
   OWASP A03/A08:2025 and its CICD-SEC risk ID. Include:
   - tool provenance (zizmor version, mode, persona, `log_warnings`; opengrep
     block)
   - the full checklist table, pass/fail/N/A per item
   - dismissed zizmor findings, one line each
