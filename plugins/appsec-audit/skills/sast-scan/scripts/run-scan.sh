#!/usr/bin/env bash
# run-scan.sh — deterministic SAST runner for the appsec-audit plugin.
#
# Builds every opengrep/semgrep command itself so that the security properties of
# the scan (pinned rules, no telemetry, scoped packs, output outside the target)
# live in code rather than in instructions an agent might drop.
#
# Usage:
#   run-scan.sh --target DIR --out DIR [--engine opengrep|semgrep]
#               [--mode all|important] [--packs "go generic/secrets ..."]
#               [--rules-cache DIR] [--plan-only]
#
# --plan-only makes no network calls: if a rules cache is missing it reports
# the packs it would request instead of fetching.
#
# Exit codes: 0 scan completed (findings or not), 2 bad usage,
#             3 no engine, 4 rules fetch/verify failed, 5 engine failed.

set -euo pipefail

# Pinned rule sources. Bump deliberately: review the upstream diff, then update
# the SHA here (see references/rulesets.md).
# opengrep/opengrep-rules: community fork of semgrep-rules (Dec 2024).
readonly OG_REPO="https://github.com/opengrep/opengrep-rules.git"
readonly OG_SHA="f1d2b562b414783763fd02a6ed2736eaed622efa"
# trailofbits/semgrep-rules: high-signal rules for Go, Python, JS, JVM, Rust, ...
readonly TOB_REPO="https://github.com/trailofbits/semgrep-rules.git"
readonly TOB_SHA="31390b3a99c04c81522d1b37c8d1900aa2dd4094"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PLUGIN_RULES="${SCRIPT_DIR}/../../../rules"

TARGET="" OUT="" ENGINE="" MODE="all" PACKS="" PLAN_ONLY=0
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/appsec-audit"

die() { echo "error: $2" >&2; exit "$1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --engine) ENGINE="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --packs) PACKS="${2:-}"; shift 2 ;;
    --rules-cache) CACHE="${2:-}"; shift 2 ;;
    --plan-only) PLAN_ONLY=1; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) die 2 "unknown argument: $1" ;;
  esac
done

[[ -n "$TARGET" && -d "$TARGET" ]] || die 2 "--target must be an existing directory"
[[ -n "$OUT" ]] || die 2 "--out is required"
[[ "$MODE" == "all" || "$MODE" == "important" ]] || die 2 "--mode must be all|important"
TARGET="$(cd "$TARGET" && pwd)"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

# --- engine ---------------------------------------------------------------
# opengrep is preferred (LGPL, no telemetry, no account). semgrep CE is the
# fallback and always runs with --metrics=off.
if [[ -z "$ENGINE" ]]; then
  if command -v opengrep >/dev/null 2>&1; then ENGINE=opengrep
  elif command -v semgrep >/dev/null 2>&1; then ENGINE=semgrep
  else die 3 "neither opengrep nor semgrep is installed (see references/rulesets.md)"
  fi
fi
command -v "$ENGINE" >/dev/null 2>&1 || die 3 "engine '$ENGINE' not found on PATH"
ENGINE_FLAGS=()
[[ "$ENGINE" == "semgrep" ]] && ENGINE_FLAGS+=(--metrics=off)
ENGINE_VERSION="$("$ENGINE" --version 2>/dev/null | head -n1 || echo unknown)"

for p in $PACKS; do
  [[ "$p" =~ ^[A-Za-z0-9_./-]+$ && "$p" != *..* ]] || die 2 "invalid pack name: $p"
done

# --- rules ----------------------------------------------------------------
OG_RULES="${CACHE}/opengrep-rules/${OG_SHA}"
TOB_RULES="${CACHE}/trailofbits-rules/${TOB_SHA}"
RULES_STATE="verified"

# ensure_rules NAME REPO SHA DIR: fetch the pinned commit if absent (never in
# --plan-only), then verify HEAD and that the tree is pristine. Untracked files
# count: a stray .yaml in a --config dir would be loaded as a rule.
ensure_rules() {
  local name="$1" repo="$2" sha="$3" dir="$4"
  if [[ ! -d "$dir/.git" ]]; then
    [[ $PLAN_ONLY -eq 1 ]] && return 1
    echo "fetching ${name}@${sha:0:12} into ${dir}" >&2
    rm -rf "$dir"
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" fetch -q --depth 1 "$repo" "$sha" || die 4 "failed to fetch ${name}"
    git -C "$dir" -c advice.detachedHead=false checkout -q FETCH_HEAD || die 4 "failed to check out ${name}"
  fi
  [[ "$(git -C "$dir" rev-parse HEAD)" == "$sha" ]] || die 4 "${name} cache HEAD does not match pinned SHA"
  [[ -z "$(git -C "$dir" status --porcelain --untracked-files=all)" ]] \
    || die 4 "${name} cache has local modifications or extra files; delete ${dir}"
}
ensure_rules opengrep-rules "$OG_REPO" "$OG_SHA" "$OG_RULES" || RULES_STATE="not-fetched"
ensure_rules trailofbits-rules "$TOB_REPO" "$TOB_SHA" "$TOB_RULES" || RULES_STATE="not-fetched"

# Map a pack name to the Trail of Bits directory that covers it, if any.
tob_pack() {
  case "$1" in
    go|python|javascript|ruby|swift|yaml/github-actions|yaml/docker-compose) echo "$1" ;;
    java|kotlin|scala) echo jvm ;;
    rust) echo rs ;;
    terraform) echo hcl ;;
  esac
}

# --- pack selection ---------------------------------------------------------
if [[ -z "$PACKS" ]]; then
  if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    FILES="$(git -C "$TARGET" ls-files)"
  else
    FILES="$(cd "$TARGET" && find . -type f -not -path './.git/*' | sed 's|^\./||')"
  fi
  has() { grep -qE "$1" <<<"$FILES"; }
  PACKS="generic/secrets"
  has '\.go$'                         && PACKS+=" go"
  has '\.py$'                         && PACKS+=" python"
  has '\.(js|jsx|mjs|cjs)$'           && PACKS+=" javascript"
  has '\.(ts|tsx)$'                   && PACKS+=" typescript javascript"
  has '\.java$'                       && PACKS+=" java"
  has '\.kt$'                         && PACKS+=" kotlin"
  has '\.cs$'                         && PACKS+=" csharp"
  has '\.php$'                        && PACKS+=" php"
  has '\.rb$'                         && PACKS+=" ruby"
  has '\.rs$'                         && PACKS+=" rust"
  has '\.scala$'                      && PACKS+=" scala"
  has '\.swift$'                      && PACKS+=" swift"
  has '\.(c|h|cc|cpp|hpp)$'           && PACKS+=" c"
  has '\.(sh|bash)$'                  && PACKS+=" bash"
  has '\.tf$'                         && PACKS+=" terraform"
  has '(^|/)Dockerfile[^/]*$'         && PACKS+=" dockerfile"
  has '(^|/)docker-compose[^/]*\.ya?ml$' && PACKS+=" yaml/docker-compose"
  has '^\.github/workflows/.*\.ya?ml$'   && PACKS+=" yaml/github-actions"
  has '\.(html|jinja2?|j2)$'          && PACKS+=" html"
  PACKS="$(tr ' ' '\n' <<<"$PACKS" | awk 'NF && !seen[$0]++' | tr '\n' ' ')"
fi

CONFIG_ARGS=()
APPLIED=()
# add_pack LABEL DIR: add DIR as a --config once; in --plan-only without a
# cache, record what would be requested.
add_pack() {
  local label="$1" dir="$2" a
  for a in ${APPLIED[@]+"${APPLIED[@]}"}; do [[ "$a" == "$label" ]] && return 0; done
  if [[ "$RULES_STATE" == "not-fetched" ]]; then
    APPLIED+=("$label")
  elif [[ -d "$dir" ]]; then
    CONFIG_ARGS+=(--config "$dir"); APPLIED+=("$label")
  else
    return 1
  fi
}
for p in $PACKS; do
  add_pack "opengrep-rules/$p" "$OG_RULES/$p" \
    || echo "warning: pack '$p' not present in opengrep-rules@${OG_SHA:0:12}, skipped" >&2
  t="$(tob_pack "$p")"
  [[ -n "$t" ]] && { add_pack "trailofbits/$t" "$TOB_RULES/$t" \
    || echo "warning: pack '$t' not present in trailofbits-rules@${TOB_SHA:0:12}, skipped" >&2; }
done
# Plugin-local rules encode OWASP cheat-sheet controls the community packs miss.
if [[ -d "$PLUGIN_RULES" ]]; then
  CONFIG_ARGS+=(--config "$PLUGIN_RULES"); APPLIED+=("appsec-audit/rules")
fi
[[ ${#APPLIED[@]} -gt 0 ]] || die 2 "no rule packs selected"

SEVERITY_ARGS=()
[[ "$MODE" == "important" ]] && SEVERITY_ARGS=(--severity WARNING --severity ERROR)

# Keep scanner output and dependency trees out of the scan.
EXCLUDES=(--exclude node_modules --exclude vendor --exclude .venv --exclude dist --exclude build)
case "$OUT" in "$TARGET"/*) EXCLUDES+=(--exclude "${OUT#"$TARGET"/}") ;; esac

jq -n --arg engine "$ENGINE" --arg version "$ENGINE_VERSION" --arg target "$TARGET" \
  --arg og "$OG_SHA" --arg tob "$TOB_SHA" --arg state "$RULES_STATE" --arg mode "$MODE" \
  --args '{engine:$engine, engine_version:$version, target:$target,
           rules:{"opengrep/opengrep-rules":$og, "trailofbits/semgrep-rules":$tob},
           rules_state:$state, mode:$mode, packs:$ARGS.positional}' "${APPLIED[@]}" \
  > "$OUT/plan.json"

if [[ $PLAN_ONLY -eq 1 ]]; then
  [[ "$RULES_STATE" == "not-fetched" ]] \
    && echo "note: rules not cached yet; packs are what would be requested (presence unchecked)" >&2
  cat "$OUT/plan.json"; exit 0
fi

# --- scan -----------------------------------------------------------------
set +e
(cd "$TARGET" && "$ENGINE" scan "${ENGINE_FLAGS[@]}" "${CONFIG_ARGS[@]}" "${SEVERITY_ARGS[@]}" \
  "${EXCLUDES[@]}" --json-output="$OUT/results.json" --sarif-output="$OUT/results.sarif" \
  --quiet . >"$OUT/engine.log" 2>&1)
RC=$?
set -e

if [[ $RC -ne 0 || ! -s "$OUT/results.json" ]]; then
  jq --argjson rc "$RC" '. + {status:"failed", exit_code:$rc}' "$OUT/plan.json" > "$OUT/scan.json"
  tail -n 20 "$OUT/engine.log" >&2
  die 5 "$ENGINE exited $RC; see $OUT/engine.log. Do not report this as a clean scan."
fi

# Compact, context-friendly view for triage. Raw JSON/SARIF stay untouched.
# check_id carries the config path as a dotted prefix; shorten it to the pack-relative id.
jq -r --arg og "$OG_SHA" --arg tob "$TOB_SHA" '.results[] | [
    .extra.severity,
    (.check_id | if test("\\." + $og + "\\.") then sub("^.*\\." + $og + "\\."; "opengrep-rules.")
                 elif test("\\." + $tob + "\\.") then sub("^.*\\." + $tob + "\\."; "trailofbits.")
                 else sub("^.*\\.rules\\."; "appsec-audit.") end),
    "\(.path):\(.start.line)",
    ((.extra.metadata.cwe // []) | if type=="array" then join(",") else . end),
    ((.extra.metadata.owasp // []) | if type=="array" then join(",") else . end),
    (.extra.message | gsub("[\\n\\t]+"; " ") | .[0:200])
  ] | @tsv' "$OUT/results.json" \
  | awk -F'\t' 'BEGIN{OFS="\t"; r["ERROR"]=1; r["WARNING"]=2; r["INFO"]=3} {print (r[$1] ? r[$1] : 9), $0}' \
  | sort -t$'\t' -k1,1n -k3,3 | cut -f2- > "$OUT/findings.tsv"

jq --argjson rc "$RC" --slurpfile r "$OUT/results.json" '. + {
    status: "completed", exit_code: $rc,
    files_scanned: ($r[0].paths.scanned | length),
    findings: ($r[0].results | length),
    by_severity: ($r[0].results | group_by(.extra.severity) | map({key: .[0].extra.severity, value: length}) | from_entries),
    engine_errors: ($r[0].errors | length)
  }' "$OUT/plan.json" > "$OUT/scan.json"

cat "$OUT/scan.json"
