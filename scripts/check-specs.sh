#!/usr/bin/env bash
# Checks the conformance specs parse and follow the suite's conventions.
# Parsing only needs a throwaway Gauge project; no language runner.
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo '{"Language": "js", "Plugins": []}' > "$tmp/manifest.json"
cp -r conformance/specs "$tmp/specs"

gauge() { if type -P gauge >/dev/null; then command gauge "$@"; else npx --yes @getgauge/cli@1.6.38 "$@"; fi; }
(cd "$tmp" && gauge format specs >/dev/null)

status=0
for f in conformance/specs/*.spec; do
  # SDKs pick specs by tag (couchdb-android runs a subset), so every spec needs one.
  grep -Eqi '^tags:' "$f" || { echo "$f: no Tags: line" >&2; status=1; }
  # Every step parameter is a quoted string; a bare number usually means a
  # value that every SDK would have to parse out of the step text.
  if grep -nE '^\* ' "$f" | sed -E 's/"[^"]*"//g' | grep -E '^[0-9]+:.*[0-9]'; then
    echo "$f: step with an unquoted number (quote parameters)" >&2; status=1
  fi
done
exit "$status"
