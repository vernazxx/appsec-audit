# Security policy

`appsec-audit` is a Claude Code plugin that runs security tooling and reads
untrusted repository content, so bugs in it can have security impact. Please
report them privately.

## Supported versions

There are no tagged releases yet. Only the latest commit on `main` is
supported; fixes land there and the plugin `version` in
`plugins/appsec-audit/.claude-plugin/plugin.json` is bumped.

## Reporting a vulnerability

Use GitHub's private reporting:
**[Report a vulnerability](https://github.com/vernazxx/appsec-audit/security/advisories/new)**
(Security tab → *Report a vulnerability*).

Please don't open a public issue or pull request for a vulnerability.

Include what you can:

- the affected file (skill, agent, command, script or rule) and commit SHA
- steps to reproduce, ideally a minimal repository that triggers it
- the impact you observed and the Claude Code version and permission mode used

This is a one-person project. I aim to acknowledge reports within 7 days and
will keep you updated in the advisory until it's fixed or closed. I'm happy to
credit you in the advisory unless you prefer otherwise.

## Scope

In scope:

- prompt injection in scanned code, comments or CI files that makes the agent
  or skills run commands, change files, or hide or misreport findings
- bypassing the integrity checks in `run-scan.sh` or `install-opengrep.sh`
  (rules SHA verification, clean cache checks, sha256 or cosign verification)
- command or argument injection in the bundled shell scripts
- leaking the `gh` token or other credentials during online zizmor audits
- a failed or partial scan being reported as clean

Out of scope, please report upstream:

- vulnerabilities in opengrep, zizmor, Aikido, the third-party rule sets, or
  Claude Code itself
- findings in the code you scanned with the plugin
