#!/usr/bin/env bash
# run-zizmor.sh — deterministic zizmor runner for the appsec-audit plugin.
#
# Audits GitHub Actions workflows, composite actions, Dependabot and pre-commit
# configs with zizmor (https://docs.zizmor.sh). Offline by default; --online
# enables the GitHub-API audits (impostor-commit, ref-confusion,
# known-vulnerable-actions, ref-version-mismatch, stale-action-refs, ...)
# using the gh CLI token, passed via environment only, never argv.
#
# Usage:
#   run-zizmor.sh --target DIR --out DIR [--persona regular|pedantic|auditor]
#                 [--online] [--ephemeral]
#
# --ephemeral: if zizmor isn't installed, download the version pinned in
# zizmor-requirements.txt, verified with pip --require-hashes, run it from a
# temp dir and delete it afterwards. Needs python3 with pip.
#
# Exit codes: 0 audit completed (findings or not) or no inputs found,
#             2 bad usage, 3 zizmor unavailable, 5 zizmor failed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Hash-pinned lock used only with --ephemeral. Bump deliberately (see its header).
readonly LOCK="${SCRIPT_DIR}/zizmor-requirements.txt"

TARGET="" OUT="" PERSONA="auditor" ONLINE=0 EPHEMERAL=0

die() { echo "error: $2" >&2; exit "$1"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --out) OUT="${2:-}"; shift 2 ;;
    --persona) PERSONA="${2:-}"; shift 2 ;;
    --online) ONLINE=1; shift ;;
    --ephemeral) EPHEMERAL=1; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) die 2 "unknown argument: $1" ;;
  esac
done

[[ -n "$TARGET" && -d "$TARGET" ]] || die 2 "--target must be an existing directory"
[[ -n "$OUT" ]] || die 2 "--out is required"
case "$PERSONA" in regular|pedantic|auditor) ;; *) die 2 "--persona must be regular|pedantic|auditor" ;; esac
TARGET="$(cd "$TARGET" && pwd)"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

# --- engine ---------------------------------------------------------------
ZIZMOR_PIN="$(sed -n 's/^zizmor==\([0-9][0-9.]*\) .*/\1/p' "$LOCK" 2>/dev/null | head -n1)"
[[ -n "$ZIZMOR_PIN" ]] || die 3 "cannot read the zizmor pin from ${LOCK}"

# Same approach as zizmorcore/zizmor-action: pip verifies the wheel against the
# lock's hashes; the wheel holds only the zizmor executable, so unpacking it is
# the whole install.
install_ephemeral() {
  command -v python3 >/dev/null 2>&1 && python3 -I -m pip --version >/dev/null 2>&1 \
    || die 3 "--ephemeral needs python3 with pip"
  EPH_DIR="$(mktemp -d)"
  trap 'rm -rf "$EPH_DIR"' EXIT
  python3 -I -m pip download --quiet --no-input --disable-pip-version-check \
    --only-binary=:all: --no-deps --require-hashes \
    --dest "$EPH_DIR/wheel" --requirement "$LOCK" >&2 \
    || die 3 "hash-verified download of zizmor==${ZIZMOR_PIN} failed"
  local wheels=("$EPH_DIR"/wheel/*.whl)
  [[ -f "${wheels[0]}" ]] || die 3 "no zizmor ${ZIZMOR_PIN} wheel for this platform"
  python3 -I -m zipfile --extract "${wheels[0]}" "$EPH_DIR/unpacked"
  local bin="$EPH_DIR/unpacked/zizmor-${ZIZMOR_PIN}.data/scripts/zizmor"
  [[ -f "$bin" ]] || die 3 "zizmor ${ZIZMOR_PIN} wheel contains no executable"
  chmod +x "$bin"
  ZIZMOR=("$bin")
}

if command -v zizmor >/dev/null 2>&1; then
  ZIZMOR=(zizmor)
elif [[ $EPHEMERAL -eq 1 ]]; then
  install_ephemeral
else
  die 3 "zizmor not installed (see references/zizmor.md); --ephemeral runs hash-verified zizmor==${ZIZMOR_PIN}"
fi
VERSION="$("${ZIZMOR[@]}" --version 2>/dev/null | head -n1 || echo unknown)"

# --- operating mode -------------------------------------------------------
MODE_ARGS=(--offline)
MODE="offline"
TOKEN=""
if [[ $ONLINE -eq 1 ]]; then
  command -v gh >/dev/null 2>&1 || die 2 "--online needs the gh CLI"
  TOKEN="$(gh auth token 2>/dev/null)" || die 2 "--online needs 'gh auth login'"
  MODE_ARGS=()
  MODE="online"
fi

COMMON=(--persona "$PERSONA" "${MODE_ARGS[@]}" --collect=default)

# Strip ambient tokens so offline really is offline, and online uses exactly the
# gh CLI token. Exported in a subshell: never on a command line, where /proc shows it.
run_zizmor() (
  unset GH_TOKEN GITHUB_TOKEN ZIZMOR_GITHUB_TOKEN
  [[ -n "$TOKEN" ]] && export ZIZMOR_GITHUB_TOKEN="$TOKEN"
  exec "${ZIZMOR[@]}" "${COMMON[@]}" "$@" "$TARGET"
)

# --- audit ----------------------------------------------------------------
set +e
run_zizmor --format=json >"$OUT/zizmor.json" 2>"$OUT/zizmor.log"
RC=$?
set -e

plan() {
  jq -n --arg v "$VERSION" --arg t "$TARGET" --arg m "$MODE" --arg p "$PERSONA" \
    --argjson rc "$1" --arg s "$2" \
    '{tool:"zizmor", version:$v, target:$t, mode:$m, persona:$p, exit_code:$rc, status:$s}'
}

case "$RC" in
  0|11|12|13|14) ;;
  3)
    plan "$RC" "no-inputs" > "$OUT/scan.json"
    cat "$OUT/scan.json"
    echo "zizmor collected no workflows, actions, Dependabot or pre-commit configs" >&2
    exit 0 ;;
  *)
    plan "$RC" "failed" > "$OUT/scan.json"
    tail -n 20 "$OUT/zizmor.log" >&2
    die 5 "zizmor exited $RC; see $OUT/zizmor.log. Do not report this as a clean audit." ;;
esac

# SARIF for tooling and code-scanning upload; never fails on findings.
run_zizmor --format=sarif >"$OUT/zizmor.sarif" 2>>"$OUT/zizmor.log" || echo "warning: SARIF pass failed" >&2

# Compact view: severity, confidence, audit, location (1-based), annotation, docs.
jq -r --arg t "$TARGET/" '.[] |
  ((.locations | map(select(.symbolic.kind == "Primary")) | first) // .locations[0]) as $loc |
  [ .determinations.severity,
    .determinations.confidence,
    .ident,
    "\($loc.symbolic.key | to_entries[0].value | (.verbatim_path // .path // tostring) | ltrimstr($t) | sub("^\\./"; "")):\($loc.concrete.location.start_point.row + 1)",
    ((($loc.symbolic.annotation // "") + " — " + .desc) | gsub("[\\n\\t]+"; " ")),
    .url
  ] | @tsv' "$OUT/zizmor.json" \
  | awk -F'\t' 'BEGIN{OFS="\t"; r["High"]=1; r["Medium"]=2; r["Low"]=3; r["Informational"]=4}
                {print (r[$1] ? r[$1] : 9), $0}' \
  | sort -t$'\t' -k1,1n -k4,4 -k5,5 | cut -f2- > "$OUT/findings.tsv"

WARNINGS="$(grep -c ' WARN ' "$OUT/zizmor.log" || true)"
plan "$RC" "completed" | jq --slurpfile z "$OUT/zizmor.json" --argjson w "${WARNINGS:-0}" '. + {
    log_warnings: $w,
    findings: ($z[0] | length),
    by_severity: ($z[0] | group_by(.determinations.severity) | map({key: .[0].determinations.severity, value: length}) | from_entries),
    by_audit: ($z[0] | group_by(.ident) | map({key: .[0].ident, value: length}) | from_entries)
  }' > "$OUT/scan.json"

cat "$OUT/scan.json"
