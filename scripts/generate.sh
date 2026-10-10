#!/usr/bin/env bash
# Usage: scripts/generate.sh <language> [spec_path] [output_dir]
#   spec_path  defaults to ../couchdb-openapi/openapi.yaml
#   output_dir defaults to ../couchdb-<language>
# Env: ALLOW_DIRTY_SPEC=1 permits generating from an uncommitted spec (recorded as spec_dirty=true).
set -euo pipefail
cd "$(dirname "$0")/.."

lang="${1:?language required, e.g. python}"
spec="${2:-../couchdb-openapi/openapi.yaml}"
out="${3:-../couchdb-${lang}}"
config="config/${lang}.yaml"

[[ -f "$config" ]] || { echo "no config for $lang at $config" >&2; exit 1; }
[[ -f "$spec" ]] || { echo "spec not found: $spec" >&2; exit 1; }

# Provenance must describe what was generated, not what HEAD happens to be.
# A dirty spec or generator tree makes HEAD a lie, so refuse unless overridden.
spec_dir="$(cd "$(dirname "$spec")" && pwd)"
spec_file="$(basename "$spec")"
spec_dirty=false
if git -C "$spec_dir" rev-parse --git-dir >/dev/null 2>&1; then
  if [[ -n "$(git -C "$spec_dir" status --porcelain -- "$spec_file")" ]]; then
    spec_dirty=true
    [[ -n "${ALLOW_DIRTY_SPEC:-}" ]] || {
      echo "refusing: $spec has uncommitted changes; commit it or set ALLOW_DIRTY_SPEC=1" >&2
      exit 1
    }
    echo "warning: generating from uncommitted $spec (recorded as spec_dirty=true)" >&2
  fi
fi

gen_dirty=false
if [[ -n "$(git status --porcelain -- config templates scripts openapitools.json 2>/dev/null)" ]]; then
  gen_dirty=true
  [[ -n "${ALLOW_DIRTY_SPEC:-}" ]] || {
    echo "refusing: generator config/templates/scripts have uncommitted changes; commit them or set ALLOW_DIRTY_SPEC=1" >&2
    exit 1
  }
  echo "warning: generator has uncommitted changes (recorded as generator_dirty=true)" >&2
fi

# Lockstep versioning: every SDK ships with the spec's info.version.
version="$(awk '/^info:/{f=1;next} f&&/^  version:/{print $2;exit}' "$spec")"
[[ -n "$version" ]] || { echo "could not read info.version from $spec" >&2; exit 1; }

npx --yes @openapitools/openapi-generator-cli generate \
  -i "$spec" -c "$config" -o "$out" \
  --additional-properties="packageVersion=${version}"

# Record provenance so the SDK repo knows exactly what built it. spec_sha256 identifies
# the spec bytes even when git cannot (no repo, or dirty); spec_sha is the commit HEAD.
spec_sha="$(git -C "$spec_dir" rev-parse --short HEAD 2>/dev/null || echo unknown)"
spec_sha256="$(sha256sum "$spec" | cut -d' ' -f1)"
gen_sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
cat > "$out/.generated-from" <<META
spec_version=$version
spec_sha=$spec_sha
spec_sha256=$spec_sha256
spec_dirty=$spec_dirty
generator_sha=$gen_sha
generator_dirty=$gen_dirty
openapi_generator=$(node -p "require('./openapitools.json')['generator-cli'].version")
META
echo "generated $lang SDK $version into $out"
