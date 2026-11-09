---
description: "Run a pinned opengrep (fallback semgrep CE) SAST scan with OWASP-aligned rules, then triage every result. Optional Aikido scan with explicit consent."
argument-hint: "[path] [--mode all|important] [--packs \"go generic/secrets ...\"]"
allowed-tools: Bash Read Grep Glob AskUserQuestion
---

# SAST scan

Use the `appsec-audit:sast-scan` skill.

1. Target = first non-flag argument in `$ARGUMENTS`, else the repo root. Pass
   `--mode`/`--packs` through unchanged.
2. Output dir: `${TMPDIR:-/tmp}/appsec-audit/<repo>-<UTC timestamp>`.
3. Run:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/skills/sast-scan/scripts/run-scan.sh" --target <abs target> --out <out> [flags]
   ```
4. Exit code `3` (no engine): show the install guidance from the skill's
   `references/rulesets.md` and stop. `4`/`5`: report the failure verbatim and
   stop. Don't hand-run scanners instead.
5. Triage every row of `findings.tsv` per `references/triage.md`.
6. Print: provenance block, confirmed findings (reporting format), needs-verification
   list, and dismissed false positives with one-line reasons.
