---
description: "Full security code review by the senior security auditor agent: threat model, opengrep SAST (Aikido optional), OWASP Top 10:2025 + Cheat Sheet manual review, CI/supply-chain checks, verified findings and a ship/no-ship verdict."
argument-hint: "[path | diff [base] | pr <number>]"
allowed-tools: Agent Bash(git rev-parse:*) Bash(git diff:*) Bash(gh pr view:*) AskUserQuestion
---

# Security review

**1. Resolve scope** from `$ARGUMENTS`:

| Argument | Scope |
|---|---|
| empty or a path | that path (default: repo root `git rev-parse --show-toplevel`) |
| `diff` / `diff <base>` | `git diff --merge-base <base or main>`: changed files plus enough context to judge them |
| `pr <n>` | GitHub PR `<n>`: `gh pr view <n>` and `gh pr diff <n>` |

If the path doesn't exist or the PR can't be fetched, stop and say so.

**2. Aikido consent (only if Aikido MCP tools are available).** Ask once
with AskUserQuestion whether code in scope may be uploaded to Aikido. Pass the
answer to the agent. If the tools aren't available, tell the agent "Aikido:
unavailable".

**3. Delegate** to the `appsec-audit:senior-security-auditor` agent with:
- the resolved scope (absolute paths, diff base or PR number) and HEAD SHA
- the Aikido decision
- "Return the full report in the reporting.md format. Do not modify files."

**4. Present** the agent's report as returned. Don't soften the verdict or
drop findings. If the agent reports failed tooling or partial coverage, keep
that up front.
