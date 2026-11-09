# Severity, confidence and report format

## Severity (impact × exploitability, in this deployment)

| Severity | Typical shape |
|---|---|
| **Critical** | Unauthenticated remote code execution, auth bypass to admin, mass data exposure, a live production secret in the repo, CI that runs untrusted code with write tokens or release secrets |
| **High** | Authenticated RCE/SQLi, IDOR on sensitive data, SSRF reaching cloud metadata or internal admin, stored XSS in privileged views, signature/TLS verification bypass |
| **Medium** | Reflected XSS, CSRF on state changes, SSRF limited to internal reads, missing rate limits on auth, unpinned third-party actions with no secrets, verbose errors leaking internals |
| **Low** | Defence-in-depth gaps: missing secondary headers, weak but unexploited config, version banners, unsigned release artifacts |
| **Info** | Hardening suggestions, code-quality issues with security flavour, accepted risks worth recording |

Adjust one level up or down for reachability (internet vs. local CLI), required
privileges, user interaction and blast radius. State the adjustment.

## Confidence

- **Confirmed**: path traced end to end, or reproduced with a local test.
- **Likely**: path traced; one assumption about runtime config stated.
- **Needs verification**: plausible; list exactly what would confirm or refute it.

## Finding format

````markdown
### [SEV-ID] <Title: the bug, not the category>

| Severity | Confidence | OWASP | CWE |
|---|---|---|---|
| High | Confirmed | A01:2025 Broken Access Control | CWE-639 |

**Location:** `path/file.go:42` (also `path/other.go:17`)

**What's wrong.** Two or three sentences. The defect, not a definition of the category.

**Attack path.**
1. Attacker sends `GET /invoices/1337` with their own session (source: `r.PathValue("id")`, handler.go:38).
2. `store.Invoice(id)` loads by ID only (store.go:91). No owner check.
3. Response returns another tenant's invoice (sink: handler.go:47).

**Evidence.**
```go
// handler.go:38-47
```

**Fix.** Concrete change, with code:
```go
inv, err := store.InvoiceForOwner(ctx, id, session.UserID)
```
Per OWASP Authorization Cheat Sheet: deny by default, enforce ownership in the data layer.

**References.** Cheat sheet URL(s), CWE URL.
````

IDs: `C-1`, `H-1`, `M-1`, `L-1`, `I-1` in severity order.

## Report layout

1. **Verdict**: one paragraph. Would you ship this? What must change before
   you would? No hedging.
2. **Scope and threat model**: what was reviewed (commit SHA, paths or diff
   range), assets, entry points, trust boundaries, and what was out of scope.
3. **Summary table**: ID | Title | Severity | Confidence | OWASP | Location.
4. **Findings**: in severity order, using the format above.
5. **OWASP coverage**: A01–A10, each "finding IDs", "checked, nothing found"
   or "N/A (reason)".
6. **Tooling provenance**: SAST block from the `sast-scan` skill, dependency
   tools run, anything that failed or was skipped.
7. **Positive observations**: at most 3 bullets. Controls done well that
   should be preserved.
8. **False positives dismissed**: one line each (rule, location, reason), so
   the next reviewer doesn't redo the work.

Never paste live secrets into the report. Show the first 4 characters,
redacted, plus file:line, and recommend rotation.
