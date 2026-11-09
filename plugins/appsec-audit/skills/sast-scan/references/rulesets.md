# Engines and rulesets

## Engines

| Engine | Why | Telemetry | Notes |
|---|---|---|---|
| **opengrep** (preferred) | LGPL-2.1 fork of Semgrep CE, same rule syntax, cross-function taint in OSS | none | https://github.com/opengrep/opengrep |
| semgrep CE (fallback) | widely installed | **on by default** | script always passes `--metrics=off` |

### Installing opengrep with verification

Don't pipe `install.sh` to a shell. Download the release binary, check it
against a pinned sha256, and verify its keyless cosign signature against the
**exact** release workflow and branch for that version. Matching any opengrep
workflow (`--certificate-identity-regexp "https://github.com/opengrep/opengrep.+"`)
would also accept a binary signed by an unrelated workflow in that repo.

```bash
V=v1.33.1   # past the release cooldown (>= 7 days old); read the release notes
A=opengrep_manylinux_x86        # or _aarch64 / opengrep_osx_arm64 / ...
base="https://github.com/opengrep/opengrep/releases/download/$V"
# Record the expected sha256 (GitHub's asset digest) and pin it wherever you
# install from, so a later swap of the asset is caught.
SHA=$(gh api "repos/opengrep/opengrep/releases/tags/$V" \
  --jq ".assets[] | select(.name == \"$A\") | .digest" | sed 's/^sha256://')
curl -fsSL --proto '=https' -O "$base/$A" -O "$base/$A.sig" -O "$base/$A.cert"
echo "$SHA  $A" | sha256sum -c -
cosign verify-blob \
  --certificate "$A.cert" --signature "$A.sig" \
  --certificate-identity "https://github.com/opengrep/opengrep/.github/workflows/rolling-release.yml@refs/heads/release-$V" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "$A" && install -m 0755 "$A" ~/.local/bin/opengrep
```

cosign 3 warns that `--certificate`/`--signature` are deprecated in favour of
`--bundle`; opengrep publishes a separate `.sig` and `.cert`, so they're still
the right flags. Run the scan with the installed version's `--version` recorded
in the provenance block.

If cosign is unavailable, say so and let the user decide. Don't skip verification silently.

## Rules

Two sources, each pinned by commit SHA in `run-scan.sh` and fetched into
`~/.cache/appsec-audit/` (`--rules-cache DIR` changes that parent dir). Before
every scan the script checks each cache's HEAD and refuses to run if the tree
has modifications or untracked files: an extra `.yaml` in a `--config` dir would
be loaded as a rule.

| Source | Pin | Notes |
|---|---|---|
| `opengrep/opengrep-rules` | `OG_SHA` | Community fork of `semgrep-rules` taken before the Semgrep Rules License change. Upstream says these are "intended for research, testing & benchmarking", so treat them as leads |
| `trailofbits/semgrep-rules` | `TOB_SHA` | Fewer, higher-signal rules (Go, Python, JS, JVM, Rust, Ruby, Swift, HCL, GitHub Actions). Same pin as the hhaudit project's `Makefile` |

`--plan-only` makes no network calls. If a cache is missing it lists the packs
it would request, unchecked, with `rules_state: "not-fetched"` in `plan.json`.

### Pack auto-selection

| Detected | Pack(s) |
|---|---|
| always | `generic/secrets` |
| `*.go` | `go` |
| `*.py` | `python` |
| `*.js/jsx/mjs/cjs` | `javascript` |
| `*.ts/tsx` | `typescript`, `javascript` |
| `*.java` / `*.kt` / `*.cs` / `*.php` / `*.rb` / `*.rs` / `*.scala` / `*.swift` | language dir of the same name |
| C/C++ | `c` |
| shell | `bash` |
| `*.tf` | `terraform` |
| `Dockerfile*` | `dockerfile` |
| `docker-compose*.yml` | `yaml/docker-compose` |
| `.github/workflows/*.yml` | `yaml/github-actions` |
| templates | `html` |
| always | `appsec-audit/rules` (this plugin) |

Each detected pack also adds the Trail of Bits directory that covers it, when
there is one: `go`, `python`, `javascript`, `ruby`, `swift`,
`yaml/github-actions`, `yaml/docker-compose` by the same name; `java`/`kotlin`/`scala`
→ `jvm`; `rust` → `rs`; `terraform` → `hcl`.

Other useful packs to add by hand with `--packs`: `yaml/kubernetes`,
`yaml/gitlab`, `problem-based-packs/insecure-transport`, `ai`.

### Bumping the pin

1. Fetch upstream into a scratch clone (not the cache, which must stay pristine)
   and `git log --oneline <old>..origin/main`.
2. Read the diff of rules that changed: new rules, removed rules, broadened patterns.
3. Update `OG_SHA` or `TOB_SHA` in `run-scan.sh` in its own PR and explain the bump.

## Custom rules (`rules/`)

Each rule encodes an OWASP cheat-sheet control the community packs miss.
Requirements: `metadata.cwe`, `metadata.owasp` (2025 IDs), `references` to the
cheat sheet, a test file next to it with `ruleid:`/`ok:` annotations, and a
passing run of `opengrep scan --test rules/` (or `semgrep --metrics=off --test rules/`).
