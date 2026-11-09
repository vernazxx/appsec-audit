# OWASP Top 10:2025 review checklist

Source: https://owasp.org/Top10/2025/ . Cheat sheets: `https://cheatsheetseries.owasp.org/cheatsheets/<Name>_Cheat_Sheet.html`.

Each category lists what to look for, when to report, when to skip, grep seeds
(a starting point, never the whole review) and the cheat sheets to cite.

**2021 → 2025 mapping** for scanner tags: A01→A01 (SSRF from 2021 A10 now in
A01), A05:2021 Misconfiguration→A02, A06:2021 Vulnerable Components→A03
(broadened to supply chain), A02:2021 Crypto→A04, A03:2021 Injection→A05,
A04:2021 Insecure Design→A06, A07→A07, A08→A08, A09→A09. A10:2025
(Exceptional Conditions) is new.

---

## A01:2025 Broken Access Control (incl. SSRF)

**Look for:** missing or inconsistent authz on handlers. IDOR (object IDs from
the request used without an ownership check). Tenant isolation. Privilege
changes via mass assignment. Path traversal. CORS. CSRF on cookie-auth state
changes. Server-side requests to user-influenced URLs (SSRF).

**Report when**
- A handler loads `/{id}` and acts on it without checking the caller owns it or
  is allowed to see it. Check *every* verb: GET can be fine while PUT/DELETE
  aren't.
- Authz is enforced in the UI/router but not in the service layer used by another entry point (API, GraphQL resolver, job).
- Request body binds directly to models with `role`, `isAdmin`, `tenantId`, `ownerId`.
- File paths built from input without canonicalise-then-prefix-check (`filepath.Clean` alone isn't enough; check `filepath.Rel`/`os.Root`).
- `Access-Control-Allow-Origin` reflects the request origin, or is `*` together with credentials.
- An outbound request uses a URL/host from input with no scheme allowlist, no
  block on private/link-local/metadata ranges *after DNS resolution*, or follows
  redirects into those ranges.

**Skip when:** the resource is intentionally public and the response contains
nothing sensitive. The SSRF target is fixed, or the only variable part is a
validated path segment on a fixed host.

**Grep seeds:** `Param("id")`, `r.PathValue(`, `req.params.id`, `findById`,
`get_object_or_404` without a user filter, `BindJSON`, `**request.json`,
`Access-Control-Allow-Origin`, `http.Get(`, `requests.get(`, `fetch(`,
`url.Parse(`, `169.254.169.254`, `filepath.Join(` with input.

**Cheat sheets:** Authorization, Access_Control, Insecure_Direct_Object_Reference_Prevention,
Mass_Assignment, Multi_Tenant_Security, Cross-Site_Request_Forgery_Prevention,
Server_Side_Request_Forgery_Prevention, Unvalidated_Redirects_and_Forwards, File_Upload.

---

## A02:2025 Security Misconfiguration

**Look for:** insecure defaults and fail-open switches. Debug/verbose modes.
Default credentials. Permissive CORS and cookies. Missing security headers.
Verbose errors. Cloud/IaC/container misconfiguration. XXE-enabled parsers.

**Report when**
- The *unset* value of a security switch is the insecure one (`DEBUG` defaults
  true, `REQUIRE_AUTH` defaults false, `VERIFY_TLS` defaults false).
- Fallback secrets: `os.Getenv("JWT_SECRET")` with a hard-coded fallback, or the
  app starts with an empty key.
- Session cookies lack `Secure`, `HttpOnly`, or `SameSite`, or have overly broad `Domain`.
- Web responses lack baseline headers: `Content-Security-Policy`,
  `Strict-Transport-Security: max-age=63072000; includeSubDomains; preload`,
  `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`,
  `X-Frame-Options: DENY` or CSP `frame-ancestors 'none'`, plus
  `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy` and `Permissions-Policy` as fitting.
  `X-Powered-By`/`Server` version banners present.
- Containers run as root, use `:latest` or unpinned bases, `--privileged`, or mount the docker socket.
- IaC: public buckets, `0.0.0.0/0` on admin ports, wildcard IAM, unencrypted storage.
- XML parsers with external entities or DTDs enabled.

**Skip when:** the insecure default only applies in an explicit dev profile
that can't be selected in prod (verify how the profile is chosen).

**Grep seeds:** `getenv(.*,\s*["']`, `DEBUG`, `InsecureSkipVerify`,
`verify=False`, `rejectUnauthorized`, `cors(`, `SameSite`, `HttpOnly`,
`USER root`, `FROM .*:latest`, `privileged`, `resolve_entities`, `DocumentBuilderFactory`.

**Cheat sheets:** HTTP_Headers, Content_Security_Policy,
HTTP_Strict_Transport_Security, Session_Management, Docker_Security,
Kubernetes_Security, Infrastructure_as_Code_Security,
XML_External_Entity_Prevention, Error_Handling. Also the OWASP Secure Headers Project:
https://owasp.org/www-project-secure-headers/

---

## A03:2025 Software Supply Chain Failures

**Look for:** vulnerable or abandoned dependencies. Unpinned versions or actions.
Install-time scripts. Typosquats. Dependency confusion. Lockfiles not enforced.
CI that can be influenced by untrusted contributors. Unsigned release artifacts.

**Report when**
- Reachable known-vulnerable dependency (`govulncheck` "called" findings; npm/pip advisories on used code paths).
- GitHub Actions referenced by tag/branch instead of full SHA. Container images without digest.
- Builds don't enforce the lockfile (`npm install` instead of `npm ci`, `go build` without `-mod=readonly` in CI, `pip install` without hashes).
- Private package names resolvable from a public registry (dependency confusion).
- Release pipeline produces artifacts with no checksums, signatures or provenance (lower severity; recommend cosign/attestations/SBOM).
- For CI/CD specifics, run the `ci-supply-chain-audit` skill.

**Skip when:** a vulnerable dependency is only in a dev/test tool that never
runs on untrusted input. Note it as Info.

**Grep seeds:** `uses: .*@v`, `uses: .*@main`, `FROM ` without `@sha256`,
`curl .* | (ba)?sh`, `postinstall`, `go run .*@latest`, `pip install` (no `--require-hashes`).

**Cheat sheets:** Software_Supply_Chain_Security, Vulnerable_Dependency_Management,
Dependency_Graph_SBOM, NPM_Security, CI_CD_Security, GitHub_Actions_Security,
Third_Party_Javascript_Management.

---

## A04:2025 Cryptographic Failures

**Look for:** sensitive data in cleartext (transport/storage/logs). Weak or
home-grown crypto. Bad randomness. Hard-coded keys. Bad password hashing.
TLS verification disabled. JWT misuse.

**Report when**
- Passwords hashed with anything other than Argon2id, scrypt, bcrypt (cost ≥ 10) or PBKDF2 with modern iterations.
- MD5/SHA1 used for security purposes (signatures, password hashing, integrity of untrusted data). DES/3DES/RC4/ECB mode. Static or reused IVs/nonces with GCM/CTR.
- Security tokens from non-CSPRNG (`math/rand`, `Math.random`, `random.random`).
- Secrets committed to the repo (verify they're real, then treat as compromised: rotate).
- TLS verification disabled, or TLS < 1.2 allowed.
- JWT: `alg: none` accepted, algorithm not pinned (RS/HS confusion), no `exp`/`aud`/`iss` validation, secrets that are short or default.
- Constant-time comparison missing for MACs/tokens (`==` on HMACs).

**Skip when:** MD5/SHA1 is used for non-security checksums or cache keys. Say so
in one line.

**Grep seeds:** `md5`, `sha1`, `DES`, `ECB`, `math/rand`, `Math.random`,
`InsecureSkipVerify`, `MinVersion`, `jwt.Parse`, `algorithms=`, `== hmac`,
`BEGIN .*PRIVATE KEY`.

**Cheat sheets:** Cryptographic_Storage, Password_Storage, Key_Management,
Secrets_Management, Transport_Layer_Security, JSON_Web_Token,
Post_Quantum_Cryptography (for long-lived data).

---

## A05:2025 Injection

**Look for:** untrusted data reaching an interpreter: SQL/NoSQL/ORM raw
queries, OS commands, LDAP, XPath, template engines (SSTI), HTML/JS (XSS),
headers (CRLF), log lines, terminal output (ANSI escapes), LLM prompts that
drive tools.

**Report when**
- String concatenation or formatting builds a query or command that includes input.
- A shell is invoked (`sh -c`, `shell=True`, `exec` in Node) with input, or argv
  allows option injection (user value starting with `-` without a `--` separator).
- User input is rendered into a template string (SSTI) or marked safe/raw.
- Untrusted text reaches a terminal or log without stripping control characters (`\x1b`, `\r`, `\n`).
- LLM output is executed, `eval`'d, or used as a tool argument without validation (prompt injection → action).

**Skip when:** parameterised queries or prepared statements with bound values.
An argv-array exec of a fixed binary with validated args. Context-aware auto-escaping template engines on default settings.

**Grep seeds:** `fmt.Sprintf("SELECT`, `+ " WHERE`, `.raw(`, `$where`,
`exec.Command("sh"`, `shell=True`, `child_process.exec`, `eval(`,
`template.HTML(`, `|safe`, `dangerouslySetInnerHTML`, `innerHTML`,
`render_template_string`, `fmt.Print.*header`.

**Cheat sheets:** Injection_Prevention, SQL_Injection_Prevention,
Query_Parameterization, OS_Command_Injection_Defense, LDAP_Injection_Prevention,
XPath_Injection_Prevention, Server_Side_Template_Injection_Prevention,
Cross_Site_Scripting_Prevention, DOM_based_XSS_Prevention, Input_Validation,
NoSQL_Security, LLM_Prompt_Injection_Prevention.

---

## A06:2025 Insecure Design

**Look for:** missing controls that no amount of correct code fixes: no rate
limiting on auth/OTP/expensive endpoints, business-logic abuse (negative
quantities, replay, race conditions on balance/stock), trust in client-side
state, no resource limits, missing abuse cases. Agent/LLM tools granted more
capability than the task needs.

**Report when**
- Credential, OTP, password-reset or enumeration-prone endpoints have no throttling or lockout.
- Check-then-act races on money, inventory, quotas or one-time tokens (no transaction or row lock, no idempotency key).
- Unbounded reads: request body size, decompression ratio, pagination limits, regex on input (ReDoS), recursion depth on JSON/XML.
- Security decisions depend on client-provided values (price, role, `isPaid`).

**Grep seeds:** `ioutil.ReadAll(r.Body)`/`io.ReadAll(` without `MaxBytesReader`,
`limit=` from query, `gzip.NewReader`, `regexp.MustCompile(` with user input,
`SELECT ... FOR UPDATE` absence around balance updates.

**Cheat sheets:** Threat_Modeling, Abuse_Case, Business_Logic_Security,
Secure_Product_Design, Denial_of_Service, Transaction_Authorization,
Bot_Management_and_Anti-Automation, AI_Agent_Security, MCP_Security.

---

## A07:2025 Authentication Failures

**Look for:** credential stuffing exposure, weak password policy, broken
session lifecycle, insecure password reset, MFA bypass, user enumeration,
OAuth/OIDC/SAML misuse.

**Report when**
- Session ID not rotated on login or privilege change. No server-side invalidation on logout. Long-lived tokens with no revocation.
- Distinct errors or timings for "unknown user" and "wrong password" on public endpoints.
- Password reset tokens are predictable, long-lived, reusable, or not bound to the user. Reset links built from the `Host` header.
- OAuth without `state`/PKCE, open `redirect_uri` matching, implicit flow, tokens in URLs.
- SAML without signature validation on the assertion, or vulnerable to XML signature wrapping.
- Hard-coded or default credentials anywhere in the auth path.

**Cheat sheets:** Authentication, Session_Management, Forgot_Password,
Credential_Stuffing_Prevention, Multifactor_Authentication, Password_Storage,
OAuth2, SAML_Security, Passkey_Security, JSON_Web_Token.

---

## A08:2025 Software or Data Integrity Failures

**Look for:** unsafe deserialization, unsigned updates or plugins, trusting
data whose integrity isn't verified (cookies, cached objects, webhooks), CI/CD
artifact tampering, prototype pollution.

**Report when**
- Untrusted data goes to native deserializers: Java `ObjectInputStream`, Python
  `pickle`/`yaml.load` (non-safe), PHP `unserialize`, .NET `BinaryFormatter`,
  Ruby `Marshal.load`.
- Webhooks are accepted without HMAC verification, or the comparison isn't constant-time.
- Auto-update or plugin loading without a signature check.
- Client-side state (cookies, hidden fields) trusted without a MAC.
- JS deep-merge or `Object.assign` of user JSON into objects (prototype pollution).

**Cheat sheets:** Deserialization, Webhook_Security, Prototype_Pollution_Prevention,
Software_Supply_Chain_Security, CI_CD_Security.

---

## A09:2025 Security Logging and Alerting Failures

**Look for:** security-relevant events not logged (auth success/failure, authz
denials, admin actions, input validation failures). Sensitive data written to
logs. Log injection. No alerting hooks.

**Report when**
- Logs contain secrets, tokens, passwords, session IDs, full card numbers or excessive PII.
- User input is logged without neutralising CR/LF or other control characters.
- Auth and authz failures are silently swallowed.

**Cheat sheets:** Logging, Logging_Vocabulary, User_Privacy_Protection.

---

## A10:2025 Mishandling of Exceptional Conditions

**Look for:** fail-open error handling. Swallowed errors. Error messages that
leak internals. Missing timeouts and resource limits. Partial state after
failure. Panics that kill the service.

**Report when**
- An auth/authz/validation error path falls through to the allowed branch (`if err != nil { log }` and then continue).
- Stack traces, SQL errors, file paths or internal hostnames are returned to clients.
- Outbound network calls lack timeouts. Default clients: Go `http.DefaultClient`
  and `http.Get`, Python `requests` without `timeout=`, Node `fetch` without
  `AbortSignal.timeout`.
- Unchecked errors on security-relevant calls (`rand.Read`, `Close` on writers that commit, signature verification).
- Unrecovered panics in request handlers or goroutines.
- Multi-step operations that don't roll back on failure (half-applied state).

**Grep seeds:** `_ = `, `except: pass`, `catch (e) {}`, `err != nil {` followed
by no return, `http.DefaultClient`, `requests.get(` without `timeout`,
`debug.PrintStack`, `traceback.format_exc()` in responses.

**Cheat sheets:** Error_Handling, Denial_of_Service, Logging.
