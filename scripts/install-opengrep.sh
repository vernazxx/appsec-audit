#!/usr/bin/env bash
# Download a pinned opengrep release binary (Linux x86_64), verify its sha256 and
# its Sigstore signature, and install it as <dir>/opengrep.
#
# Usage: scripts/install-opengrep.sh <version> <sha256> <dir>
#
# Requires curl, sha256sum and cosign. The signature must come from opengrep's
# release workflow for exactly <version>.
set -euo pipefail

version=${1:?version, e.g. v1.33.1}
sha256=${2:?sha256 of the release binary}
dir=${3:?install dir}

asset=opengrep_manylinux_x86
base="https://github.com/opengrep/opengrep/releases/download/${version}"
identity="https://github.com/opengrep/opengrep/.github/workflows/rolling-release.yml@refs/heads/release-${version}"

command -v cosign >/dev/null || { echo "error: cosign is required to verify opengrep" >&2; exit 1; }

dl="$dir/download"
rm -rf "$dl"
mkdir -p "$dl"
for f in "$asset" "$asset.sig" "$asset.cert"; do
  curl -fsSL --proto '=https' -o "$dl/$f" "$base/$f"
done

echo "${sha256}  $dl/$asset" | sha256sum -c -
cosign verify-blob \
  --certificate "$dl/$asset.cert" \
  --signature "$dl/$asset.sig" \
  --certificate-identity "$identity" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  "$dl/$asset"

install -m 0755 "$dl/$asset" "$dir/opengrep"
rm -rf "$dl"
echo "installed opengrep ${version} to $dir/opengrep" >&2
