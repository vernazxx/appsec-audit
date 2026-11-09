#!/usr/bin/env bash
# Structural checks for the marketplace and plugin manifests and component
# frontmatter. Runs in CI without Claude Code installed; locally, also run
# `claude plugin validate . && claude plugin validate plugins/appsec-audit`.
#
# Usage: scripts/check-plugin.sh   (from the repository root)
set -euo pipefail

fail=0
err() { echo "error: $*" >&2; fail=1; }

# frontmatter FILE KEY: print the value of a top-level `key:` in the leading
# YAML frontmatter (single-line or the first line of a folded `>-` block).
frontmatter() {
  awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 && index($0, key ":") == 1 {
      v = substr($0, length(key) + 2); sub(/^[ \t]+/, "", v)
      if (v == ">-" || v == ">" || v == "|") { getline v; sub(/^[ \t]+/, "", v) }
      print v; exit
    }' "$1"
}

market=.claude-plugin/marketplace.json
jq -e . "$market" >/dev/null || err "$market is not valid JSON"
jq -e '.name and .owner.name and (.plugins | length > 0)' "$market" >/dev/null \
  || err "$market needs name, owner.name and at least one plugin"

while IFS=$'\t' read -r name source; do
  [[ -d "$source" ]] || { err "$market: plugin '$name' source '$source' is not a directory"; continue; }
  manifest="$source/.claude-plugin/plugin.json"
  jq -e . "$manifest" >/dev/null || { err "$manifest is not valid JSON"; continue; }
  [[ "$(jq -r .name "$manifest")" == "$name" ]] || err "$manifest name doesn't match marketplace entry '$name'"
  jq -e '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")' "$manifest" >/dev/null || err "$manifest version isn't semver"
  jq -e '.description and .license' "$manifest" >/dev/null || err "$manifest needs description and license"

  for skill in "$source"/skills/*/SKILL.md; do
    dir="$(basename "$(dirname "$skill")")"
    [[ "$(frontmatter "$skill" name)" == "$dir" ]] || err "$skill: frontmatter name must be '$dir'"
    [[ -n "$(frontmatter "$skill" description)" ]] || err "$skill: missing description"
  done
  for agent in "$source"/agents/*.md; do
    [[ "$(frontmatter "$agent" name)" == "$(basename "$agent" .md)" ]] || err "$agent: frontmatter name must match file name"
    [[ -n "$(frontmatter "$agent" description)" ]] || err "$agent: missing description"
  done
  for cmd in "$source"/commands/*.md; do
    [[ -n "$(frontmatter "$cmd" description)" ]] || err "$cmd: missing description"
  done
  # Skills referenced by agents must exist in this plugin.
  for agent in "$source"/agents/*.md; do
    while read -r ref; do
      [[ -f "$source/skills/${ref#"$name":}/SKILL.md" ]] || err "$agent: skill '$ref' not found"
    done < <(awk '/^skills:/{f=1; next} f && /^  - /{sub(/^  - /, ""); print; next} f{exit}' "$agent")
  done
done < <(jq -r '.plugins[] | [.name, .source] | @tsv' "$market")

[[ $fail -eq 0 ]] && echo "plugin manifests and frontmatter OK"
exit "$fail"
