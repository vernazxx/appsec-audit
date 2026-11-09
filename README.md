# appsec-audit

A Claude Code plugin for security code review as a security engineer. It reviews
against the [OWASP Top 10:2025](https://owasp.org/Top10/2025/) and the
[OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/), uses
[opengrep](https://github.com/opengrep/opengrep) for SAST, and can optionally use
[Aikido](https://www.aikido.dev/) through its official MCP server. Structure and
conventions follow [Trail of Bits' skills](https://github.com/trailofbits/skills).

## Components

| Type | Name | Purpose |
|---|---|---|
| Agent | `appsec-audit:senior-security-auditor` | Senior AppSec engineer persona. Threat model → SAST → OWASP manual review → CI/supply chain → verified findings → ship/no-ship verdict. Read-only |
| Command | `/appsec-audit:security-review [path \| diff [base] \| pr <n>]` | Full review, delegated to the agent |
| Command | `/appsec-audit:sast [path] [--mode important] [--packs ...]` | Pinned SAST scan plus triage |
| Command | `/appsec-audit:ci-audit [path] [--offline] [--persona ...]` | zizmor plus opengrep plus a manual checklist for GitHub Actions, Dependabot, pre-commit and release |
| Skill | `owasp-code-review` | Methodology, A01–A10:2025 checklist (report/skip criteria, grep seeds), cheat-sheet map, severity rubric, report format |
| Skill | `sast-scan` | `run-scan.sh` (opengrep → semgrep CE fallback; opengrep-rules + Trail of Bits rules, both SHA-pinned), engine/rules provenance, Aikido gate, triage guide |
| Skill | `ci-supply-chain-audit` | `run-zizmor.sh` (offline by default, `--online` for impostor-commit and ref-confusion), mapping from zizmor audits to the checklist, 20-item GitHub Actions checklist mapped to OWASP CICD-SEC risks |
| Rules | `rules/*.yaml` | Custom OWASP-aligned opengrep rules, with tests |

## Install

```bash
# from a local checkout
claude plugin marketplace add ~/src/vernaz/appsec-audit
claude plugin install appsec-audit@appsec-audit

# or for a single session
claude --plugin-dir ~/src/vernaz/appsec-audit/plugins/appsec-audit
```

### Tooling

- **opengrep** (preferred): install from a release with cosign verification.
  See `plugins/appsec-audit/skills/sast-scan/references/rulesets.md`. If it's
  absent, the scan falls back to `semgrep` with `--metrics=off`.
- **Rules**: `opengrep/opengrep-rules` and `trailofbits/semgrep-rules`, each
  pinned by commit SHA in `run-scan.sh` and fetched on the first scan into
  `~/.cache/appsec-audit/` (`--plan-only` never fetches). No registry packs and
  no `--config auto`.
- **zizmor**: `pacman -S zizmor`, `uv tool install zizmor==1.31.1`, `brew install zizmor`
  or `cargo install --locked zizmor`. If it's missing, `run-zizmor.sh --ephemeral`
  runs the version pinned in `zizmor-requirements.txt`, verified with
  `pip --require-hashes`, after you approve. Online audits use
  `gh auth token`, exported only to the zizmor process and never put on a
  command line.
- **Aikido** (optional): install Aikido's own Claude Code plugin
  (`AikidoSec/aikido-claude-plugin`). This plugin calls its MCP tools only after
  you approve uploading the named files, and never ignores Aikido issues for you.
- `jq`, `git`, and `gh` (for PR scope and action-SHA verification).

## Security properties

- Commands are built by `run-scan.sh`, not by the model. Both rules SHAs are
  verified, the caches must be clean (no modified or untracked files), pack
  names are validated, and output stays out of the scan.
- The agent can't use Write/Edit. It still has Bash, so read-only is enforced
  by its instructions rather than a sandbox. Run it in `default` or `plan`
  permission mode if you want a prompt before each command.
- Repository content is treated as untrusted. Prompt-injection attempts in code
  or comments are reported as findings.
- Failed or partial scans are reported as such, never as clean.

## Developing

```bash
# custom rule tests
opengrep scan --test plugins/appsec-audit/rules   # or: semgrep --metrics=off --test ...
# manifest validation
claude plugin validate . && claude plugin validate plugins/appsec-audit
```

Bump the pinned rules SHA only in a dedicated change, after reading the upstream diff.

## License

[MIT](LICENSE). The plugin doesn't bundle third-party rules or binaries: the
scripts fetch them at runtime under their own licenses. Notably,
`trailofbits/semgrep-rules` is AGPL-3.0 and opengrep is LGPL-2.1; if you
redistribute those, their terms apply.
