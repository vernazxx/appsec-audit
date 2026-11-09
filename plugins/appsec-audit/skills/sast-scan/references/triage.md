# Triaging scanner results

For each row in `findings.tsv`, open the code at the reported line with enough
surrounding context to answer the questions below. Group identical rule hits
that share one root cause (e.g. one unsafe helper called from 12 places) into
one finding with all locations listed.

## Questions, in order

1. **Is the sink real?** Does the flagged call actually do the dangerous thing
   in this language/version/library (e.g. `yaml.load` vs `yaml.safe_load`,
   ORM raw vs parameterised)?
2. **Is the source attacker-influenced?** Trace backwards to an entry point:
   HTTP params/headers/body, CLI args, env in multi-tenant contexts, files,
   queue messages, DB rows written by users, CI event payloads, LLM output.
   Constants and operator-only config usually aren't, but note when "operator"
   includes untrusted CI contributors.
3. **Is there an effective control on the path?** Validation, encoding,
   allowlists, authz checks, framework auto-escaping. Effective means correct
   for *this* sink's context (HTML-escaping doesn't stop SQLi).
4. **Is it reachable?** Dead code, test-only code, build-time-only, or behind a
   feature flag that's off in prod. Lowers severity; doesn't make it a false positive.
5. **What's the impact if exploited?** Use the rubric in
   `owasp-code-review/references/reporting.md`.

## Verdicts

| Verdict | Requirement |
|---|---|
| **Confirmed** | Source → sink path shown with file:line hops, and no effective control on it |
| **Needs verification** | Plausible, but one hop can't be resolved statically. State exactly what would settle it (a test, a config value, a runtime check) |
| **False positive** | One-line reason tied to code, e.g. "value is `strconv.Atoi`-parsed int at handler.go:41" |

Write a test that proves a confirmed finding when it's cheap (httptest/unit
test against local fixtures). Never prove it against a live third-party system.

## Common false-positive patterns (still verify)

- Secrets rules on placeholders (`changeme`, `<token>`, `xxxx`) or public
  identifiers (git SHAs, public keys, OAuth client IDs for public clients).
- "Missing TLS MinVersion" on Go ≥ 1.22, where the default minimum is TLS 1.2
  for clients and servers. Check `go.mod`'s `go` line and any `GODEBUG=tls10server`
  override first. Still report where policy requires TLS 1.3.
- `exec.Command` with a constant binary and argv slices (no shell). Still
  check for argument injection (`--` and leading `-` in user values).
- Template "unescaped" rules where the value is a compile-time constant.

## Common true positives scanners under-rate

- Default `http.Client`/`requests` without timeouts in code that fetches
  user-supplied URLs (SSRF plus resource exhaustion).
- `InsecureSkipVerify`, `verify=False` or `rejectUnauthorized:false` behind an
  env var that defaults to *on*.
- Error responses echoing exception text or stack traces (A10:2025).
- Writing response headers or other remote data to the terminal unsanitised
  (ANSI escape injection, CWE-150).
