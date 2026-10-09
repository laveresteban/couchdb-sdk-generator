#!/usr/bin/env bash
# Usage: scripts/generate.sh <language> [spec_path] [output_dir]
#   spec_path  defaults to ../couchdb-openapi/openapi.yaml
#   output_dir defaults to ../couchdb-<language>
set -euo pipefail
cd "$(dirname "$0")/.."

lang="${1:?language required, e.g. python}"
spec="${2:-../couchdb-openapi/openapi.yaml}"
out="${3:-../couchdb-${lang}}"
config="config/${lang}.yaml"

[[ -f "$config" ]] || { echo "no config for $lang at $config" >&2; exit 1; }
[[ -f "$spec" ]] || { echo "spec not found: $spec" >&2; exit 1; }

# Lockstep versioning: every SDK ships with the spec's info.version.
version="$(awk '/^info:/{f=1;next} f&&/^  version:/{print $2;exit}' "$spec")"
[[ -n "$version" ]] || { echo "could not read info.version from $spec" >&2; exit 1; }

npx --yes @openapitools/openapi-generator-cli generate \
  -i "$spec" -c "$config" -o "$out" \
  --additional-properties="packageVersion=${version}"

# Record provenance so the SDK repo knows what built it.
spec_sha="$(git -C "$(dirname "$spec")" rev-parse --short HEAD 2>/dev/null || echo unknown)"
gen_sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
cat > "$out/.generated-from" <<META
spec_version=$version
spec_sha=$spec_sha
generator_sha=$gen_sha
openapi_generator=$(node -p "require('./openapitools.json')['generator-cli'].version")
META
echo "generated $lang SDK $version into $out"
