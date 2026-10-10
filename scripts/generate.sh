#!/usr/bin/env bash
# Usage: scripts/generate.sh <language> [spec_path] [sdk_repo_dir]
#   language      a key under "languages" in sdk-matrix.json (python, typescript)
#   spec_path     defaults to ../couchdb-openapi/openapi.yaml
#   sdk_repo_dir  defaults to ../<repo> from sdk-matrix.json
# Relative paths are resolved from this repo's root.
# SKIP_POST=1 skips the language's post step (used by CI on scratch dirs).
set -euo pipefail
cd "$(dirname "$0")/.."

lang="${1:?language required, e.g. python}"
spec="${2:-../couchdb-openapi/openapi.yaml}"

# Look up the language's config, target repo, output dir and post step.
entry() { node -e '
  const m = require("./sdk-matrix.json").languages[process.argv[1]];
  if (!m) { console.error(`no "${process.argv[1]}" in sdk-matrix.json`); process.exit(1); }
  console.log(m[process.argv[2]] ?? "");' "$lang" "$1"; }
config="$(entry config)"
repo_dir="${3:-../$(entry repo)}"
out="$repo_dir/$(entry output)"
post="$(entry post)"

[[ -f "$config" ]] || { echo "no config for $lang at $config" >&2; exit 1; }
[[ -f "$spec" ]] || { echo "spec not found: $spec" >&2; exit 1; }
[[ -d "$repo_dir" ]] || { echo "SDK repo not found: $repo_dir" >&2; exit 1; }

# Lockstep versioning: every SDK ships with the spec's info.version.
version="$(awk '/^info:/{f=1;next} f&&/^  version:/{print $2;exit}' "$spec")"
[[ -n "$version" ]] || { echo "could not read info.version from $spec" >&2; exit 1; }

# OpenAPI Generator never deletes files, so remember what it wrote last time
# and remove anything it no longer writes (e.g. models for removed schemas).
manifest="$out/.openapi-generator/FILES"
previous="$(cat "$manifest" 2>/dev/null || true)"

npx --yes @openapitools/openapi-generator-cli generate \
  -i "$spec" -c "$config" -o "$out" \
  --additional-properties="packageVersion=${version}"

if [[ -n "$previous" ]]; then
  comm -23 <(sort -u <<<"$previous") <(sort -u "$manifest") | while IFS= read -r stale; do
    [[ -n "$stale" && -f "$out/$stale" ]] && rm -- "$out/$stale" && echo "removed stale $stale"
  done
fi

# Record provenance so the SDK repo knows what built it.
spec_sha="$(git -C "$(dirname "$spec")" rev-parse --short HEAD 2>/dev/null || echo unknown)"
gen_sha="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
cat > "$out/.generated-from" <<META
spec_version=$version
spec_sha=$spec_sha
generator_sha=$gen_sha
openapi_generator=$(node -p "require('./openapitools.json')['generator-cli'].version")
META

if [[ -n "$post" && -z "${SKIP_POST:-}" ]]; then
  (cd "$repo_dir" && eval "$post")
fi
echo "generated $lang SDK $version into $out"
