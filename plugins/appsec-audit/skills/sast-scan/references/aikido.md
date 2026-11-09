# Aikido integration

Aikido is a SaaS platform. Its scans run in Aikido's cloud, so **source code
leaves the machine**. Treat every Aikido scan as a data-egress decision.

## Availability

This plugin doesn't bundle Aikido. Use the official integration, Aikido's
Claude Code plugin (`AikidoSec/aikido-claude-plugin`, also in the Claude
plugin marketplace). It registers the `@aikidosec/mcp` server and handles
sign-in. Tools exposed (names are prefixed by the MCP server id):

| Tool | Use |
|---|---|
| `aikido_scan_paths` | SAST + secrets on files on disk (server reads them). Preferred |
| `aikido_full_scan` | SAST + secrets on content you pass in (unsaved code) |
| `aikido_issues_list` | Read issues from the Aikido feed for the connected repo |
| `aikido_ignore_issue` | **Write.** Ignores an issue for the whole team |

If no tool name ending in `aikido_scan_paths` is available, record
"Aikido: unavailable" and move on. Do not try to install or configure it
yourself.

## Gate

Before the first Aikido call in a session, ask (AskUserQuestion):

> Aikido scans upload source to Aikido's cloud (region set by your token).
> Files: <count> under <paths>. Proceed?

Excluded from upload regardless of approval: `.env*`, `*.pem`, `*.key`,
`*id_rsa*`, `*.p12`, `*.kdbx`, files under `secrets/`, and anything the local
secrets pack already flagged. Uploading a live secret to scan it is a leak.

## Running

- Max **50 files per call**. Batch by directory, highest-risk first: request
  handlers, auth, crypto, deserialization, file/OS/network I/O, CI config.
- Pass paths, not contents, to `aikido_scan_paths`.

## Triage and dedup

- Merge Aikido results with the opengrep results on `(file, line ± 2, CWE)`.
  A hit from both engines raises confidence; it doesn't add a second finding.
- Aikido remediation text is advisory. Verify it against the OWASP cheat sheet
  before recommending it.
- **Never call `aikido_ignore_issue`** during an audit. It changes shared team
  state. Recommend the ignore with a reason and let a human do it.

## CI option (not used by the agent)

For pipelines, Aikido's local scanner (Docker) runs in CI and reports to the
platform. Pin the image by digest and pass the token via a secret. It belongs in
a separate, reviewed pipeline change, not an audit run.
