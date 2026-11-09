<p align="center">
  <img src="assets/brand/appsec-audit-icon.svg" alt="appsec-audit icon: a neon shield under a magnifier with a check mark" width="128" height="128">
</p>

<h1 align="center">appsec-audit</h1>

<p align="center"><em>Is your code what it claims to be?</em></p>

<p align="center">
  <a href="https://github.com/vernazxx/appsec-audit/actions/workflows/ci.yaml"><img src="https://github.com/vernazxx/appsec-audit/actions/workflows/ci.yaml/badge.svg?branch=main" alt="CI status"></a>
  <a href="#quick-start"><img src="https://img.shields.io/badge/Claude_Code-plugin-FF3EA5?style=flat-square&labelColor=1A0F33" alt="Claude Code plugin"></a>
  <a href="https://owasp.org/Top10/2025/"><img src="https://img.shields.io/badge/OWASP-Top_10%3A2025-FF8A1F?style=flat-square&labelColor=1A0F33" alt="OWASP Top 10:2025"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-3EF0FF?style=flat-square&labelColor=1A0F33" alt="MIT license"></a>
</p>

A [Claude Code](https://code.claude.com/docs/en/overview) plugin
that reviews code the way a senior application security engineer would. It
threat-models the target, runs pinned SAST ([opengrep](https://github.com/opengrep/opengrep))
and a GitHub Actions audit ([zizmor](https://docs.zizmor.sh)), reviews by hand
against the [OWASP Top 10:2025](https://owasp.org/Top10/2025/) and the
[OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/), verifies every
finding, and ends with a ship/no-ship verdict. It's read-only: it reports, it
doesn't change your code.

Structure and conventions follow [Trail of Bits' skills](https://github.com/trailofbits/skills).

- [Quick start](#quick-start)
- [Install options](#install-options)
- [Install the scanners](#install-the-scanners)
- [Usage](#usage)
- [Update, disable or uninstall](#update-disable-or-uninstall)
- [Troubleshooting](#troubleshooting)
- [What's inside](#whats-inside)
- [Security properties](#security-properties)
- [Developing](#developing)

## Quick start

The plugin isn't in the Anthropic plugin directory. This repository is its own
plugin marketplace, so you install it straight from GitHub. No GitHub account
or SSH key is needed; it's cloned over HTTPS.

**1. Install the plugin** (needs [Claude Code](https://code.claude.com/docs/en/setup)
and `git`):

```bash
claude plugin marketplace add vernazxx/appsec-audit
claude plugin install appsec-audit@appsec-audit
```

`appsec-audit@appsec-audit` means *plugin* `appsec-audit` from *marketplace*
`appsec-audit`; both have the same name here.

**2. Install opengrep** so scans can run. See [Install the scanners](#install-the-scanners);
it's one copy-paste on Linux x86_64. Without it, the review still runs but
reports the SAST step as not run.

**3. Restart Claude Code**, then in any repository:

```text
/appsec-audit:security-review
```

## Install options

Pick the one that fits. All of them were tested with Claude Code 2.1.319.

### A. For yourself, from GitHub (recommended)

```bash
claude plugin marketplace add vernazxx/appsec-audit
claude plugin install appsec-audit@appsec-audit
```

or in one step:

```bash
claude plugin install appsec-audit --marketplace vernazxx/appsec-audit
```

This goes in your user settings (`~/.claude/settings.json`) and works in every
project. Inside a Claude Code session, the `/plugin` command offers the same
flow: add the marketplace `vernazxx/appsec-audit`, then install `appsec-audit`.
See Claude Code's [plugin docs](https://code.claude.com/docs/en/discover-plugins)
for the interactive menu.

### B. For a team, per repository

Run this from the root of the repository your team works in:

```bash
claude plugin marketplace add vernazxx/appsec-audit --scope project
claude plugin install appsec-audit@appsec-audit --scope project
```

It writes `.claude/settings.json`. Commit that file; when teammates open Claude
Code in the repository and trust the folder, they're prompted to install the
marketplace and plugin. The file looks like this:

```json
{
  "extraKnownMarketplaces": {
    "appsec-audit": {
      "source": { "source": "github", "repo": "vernazxx/appsec-audit" }
    }
  },
  "enabledPlugins": {
    "appsec-audit@appsec-audit": true
  }
}
```

Use `--scope local` instead to enable it in one repository for yourself only
(`.claude/settings.local.json`, not committed).

### C. From a local clone

Useful offline, for reviewing the code before installing, or for development:

```bash
git clone https://github.com/vernazxx/appsec-audit.git
claude plugin marketplace add ./appsec-audit
claude plugin install appsec-audit@appsec-audit
```

The marketplace then points at your folder. Pull and run
`claude plugin marketplace update appsec-audit` to pick up changes.

### D. For one session only

Nothing is installed or written to settings:

```bash
claude --plugin-dir ./appsec-audit/plugins/appsec-audit
```

### Pinning a version

By default you track `main`. To stay on a branch or release tag, add `#<ref>`:

```bash
claude plugin marketplace add "vernazxx/appsec-audit#main"
```

The ref must be a branch or tag: `marketplace add` clones with
`git clone --branch`, so commit SHAs are rejected. Pin to a release tag once
releases are published.

### Check it worked

```bash
claude plugin list                                # appsec-audit@appsec-audit ... ✔ enabled
claude plugin details appsec-audit@appsec-audit   # skills, agent, token cost
```

In a session, type `/appsec-audit:` to see the commands, or run `/agents` to
see `senior-security-auditor`. The plugin adds about 800 tokens to every
session; the full instructions load only when a command or the agent runs.

## Install the scanners

The plugin drives local tools. It never installs them for you.

| Tool | Used for | Needed? |
|---|---|---|
| `git`, `jq` | rule fetching, result parsing | **yes** |
| **opengrep** | SAST (`/appsec-audit:sast`, full review) | **yes** for SAST. `semgrep` works as a fallback; the scripts always pass `--metrics=off` |
| **zizmor** | GitHub Actions audit (`/appsec-audit:ci-audit`) | recommended. If missing, the plugin offers a one-off, hash-verified run (needs `python3` with `pip`) |
| `gh` (logged in) | PR scope, online zizmor audits, pin verification | recommended |
| `cosign` | verifying the opengrep download | for the install below |
| Aikido | extra cloud SAST + secrets scan | optional, see below |

**opengrep** (Linux x86_64; for other platforms change `A`, see
[rulesets.md](plugins/appsec-audit/skills/sast-scan/references/rulesets.md#installing-opengrep-with-verification)).
This checks the download's sha256 and its signature from opengrep's own release
workflow before installing:

```bash
V=v1.33.1
A=opengrep_manylinux_x86
base="https://github.com/opengrep/opengrep/releases/download/$V"
SHA=$(gh api "repos/opengrep/opengrep/releases/tags/$V" \
  --jq ".assets[] | select(.name == \"$A\") | .digest" | sed 's/^sha256://')
curl -fsSL --proto '=https' -O "$base/$A" -O "$base/$A.sig" -O "$base/$A.cert"
echo "$SHA  $A" | sha256sum -c -
cosign verify-blob \
  --certificate "$A.cert" --signature "$A.sig" \
  --certificate-identity "https://github.com/opengrep/opengrep/.github/workflows/rolling-release.yml@refs/heads/release-$V" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "$A" && install -m 0755 "$A" ~/.local/bin/opengrep
opengrep --version
```

**zizmor**, any one of:

```bash
pacman -S zizmor                    # Arch
brew install zizmor                 # macOS / Linuxbrew
uv tool install zizmor==1.31.1      # PyPI, version-pinned
cargo install --locked zizmor
```

**Rules** need no install. The first scan clones `opengrep/opengrep-rules` and
`trailofbits/semgrep-rules` at pinned commits into `~/.cache/appsec-audit/` and
refuses to run if that cache is ever modified. Registry packs and
`--config auto` are never used.

**Aikido** (optional): install Aikido's own Claude Code plugin
(`AikidoSec/aikido-claude-plugin`). Aikido scans upload code to Aikido's cloud,
so this plugin asks before every upload, names the files, and never ignores
Aikido issues on your behalf.

## Usage

Run these inside Claude Code, from the repository you want to review.

```text
/appsec-audit:security-review                # whole repository
/appsec-audit:security-review src/api        # one directory
/appsec-audit:security-review diff           # your branch vs main
/appsec-audit:security-review diff develop   # your branch vs another base
/appsec-audit:security-review pr 42          # a GitHub pull request (needs gh)

/appsec-audit:sast                           # SAST only, every result triaged
/appsec-audit:sast src --mode important      # only WARNING/ERROR rules
/appsec-audit:sast --packs "go generic/secrets"

/appsec-audit:ci-audit                       # workflows, Dependabot, pre-commit, release
/appsec-audit:ci-audit --offline             # no GitHub API calls
```

You can also ask in plain words; Claude picks the matching skill or agent:

> Use the senior-security-auditor agent to review the auth package before I merge.

What you get back: a short threat model, confirmed findings with severity,
confidence, CWE, OWASP mapping, an exploit scenario and a concrete fix, an
A01–A10 coverage table, tool provenance (versions, rule SHAs, what didn't run),
and the verdict. Raw scanner output is written under
`${TMPDIR:-/tmp}/appsec-audit/<repo>-<timestamp>/`, never inside your repository.

Expect Claude Code to ask permission for the scanner commands unless you've
allowed them. The agent has no Write/Edit tools; run it in `default` or `plan`
permission mode if you want to approve every command.

## Update, disable or uninstall

```bash
claude plugin marketplace update appsec-audit     # fetch the latest catalog
claude plugin update appsec-audit@appsec-audit    # then restart Claude Code

claude plugin disable appsec-audit@appsec-audit   # keep it, turn it off
claude plugin enable appsec-audit@appsec-audit

claude plugin uninstall appsec-audit@appsec-audit
claude plugin marketplace remove appsec-audit
rm -rf ~/.cache/appsec-audit                      # cached rule repos
```

Add `--scope project` or `--scope local` to these if you installed with that scope.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Plugin "appsec-audit" not found in marketplace` | `claude plugin marketplace update appsec-audit`, then install again |
| `Remote branch <sha> not found` when adding with `#<ref>` | Commit SHAs aren't supported; use a branch or tag |
| `/appsec-audit:` commands don't appear | Restart Claude Code; check `claude plugin list` shows it **enabled** in the right scope |
| Scan stops with "neither opengrep nor semgrep is installed" (exit 3) | [Install opengrep](#install-the-scanners) and check `opengrep --version` works in the same shell |
| "… cache has local modifications or extra files" (exit 4) | Something changed the cached rules. Delete the directory named in the message; the next scan fetches it again |
| "zizmor not installed" | Install zizmor, or accept the offered one-off run (`--ephemeral`, needs `python3 -m pip`) |
| Online zizmor audits skipped | `gh auth login`, or pass `--offline` to make that explicit |
| Report says a scan "failed" | Expected behaviour: failed scans are never reported as clean. Read the log path it gives |

## What's inside

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

```text
.claude-plugin/marketplace.json      # this repo as a marketplace
plugins/appsec-audit/
  .claude-plugin/plugin.json         # plugin manifest
  agents/                            # senior-security-auditor
  commands/                          # security-review, sast, ci-audit
  skills/<skill>/SKILL.md            # methodology; references/ and scripts/ alongside
  rules/                             # custom opengrep rules + tests
  assets/appsec-audit-icon-512.png   # plugin icon ("icon" in plugin.json)
assets/brand/                        # icon, banner, palette (see its README)
scripts/                             # repo tooling (CI checks, opengrep installer)
```

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
- Online zizmor audits use `gh auth token`, exported only to the zizmor process
  and never put on a command line.

## Developing

Work on a clone and load it without installing:

```bash
git clone https://github.com/vernazxx/appsec-audit.git && cd appsec-audit
claude --plugin-dir ./plugins/appsec-audit       # restart the session to reload edits
```

Checks (CI runs the first three):

```bash
scripts/check-plugin.sh                                   # manifests and frontmatter
shellcheck scripts/*.sh plugins/*/skills/*/scripts/*.sh   # shell scripts
opengrep scan --test plugins/appsec-audit/rules           # custom rule tests
claude plugin validate . && claude plugin validate plugins/appsec-audit   # full validation, local only
```

CI (`.github/workflows/ci.yaml`) runs the manifest checks, shellcheck, the rule
tests with a sha256- and cosign-verified opengrep, a no-network `run-scan.sh`
plan, and zizmor. Actions are pinned by commit SHA; opengrep and zizmor
versions are pinned in the workflow and bumped by hand.

Contributions go through pull requests to `main`. Commits must be signed, CI
must pass, and the code owner reviews every PR. Bump a pinned rules SHA only in
a dedicated change, after reading the upstream diff.

## License

[MIT](LICENSE). The plugin doesn't bundle third-party rules or binaries: the
scripts fetch them at runtime under their own licenses. Notably,
`trailofbits/semgrep-rules` is AGPL-3.0 and opengrep is LGPL-2.1; if you
redistribute those, their terms apply.
