#!/bin/sh
# Stage the mounted python SDK's conformance project with the shared specs,
# wait for CouchDB, create the system databases, then run Gauge. The steps
# read COUCHDB_URL / COUCHDB_USER / COUCHDB_PASSWORD from the environment.
# Extra args go to `gauge run`, e.g.
#   docker compose run --rm gauge-python --tags changes
set -e
export COUCHDB_URL="${COUCHDB_URL:-http://couchdb:5984}"
cp -r /sdk/conformance/. /work
rm -rf /work/specs && cp -r /specs /work/specs
export PYTHONPATH=/sdk

echo "waiting for CouchDB at ${COUCHDB_URL} ..."
python3 - "$COUCHDB_URL" "${COUCHDB_USER:-admin}" "${COUCHDB_PASSWORD:-password}" <<'PY'
import base64, sys, time, urllib.error, urllib.request
url, user, password = sys.argv[1].rstrip("/"), sys.argv[2], sys.argv[3]
for _ in range(60):
    try:
        urllib.request.urlopen(url + "/_up", timeout=2)
        break
    except Exception:
        time.sleep(1)
else:
    sys.exit("CouchDB did not become ready")
auth = "Basic " + base64.b64encode(f"{user}:{password}".encode()).decode()
for db in ("_users", "_replicator", "_global_changes"):
    req = urllib.request.Request(f"{url}/{db}", method="PUT", headers={"Authorization": auth})
    try:
        urllib.request.urlopen(req, timeout=5)
    except urllib.error.HTTPError as e:
        if e.code != 412:  # 412: already exists
            raise
print("CouchDB is up")
PY

# Gauge passes a run whose scenarios were skipped for missing steps; fail it.
{ gauge run specs "$@"; echo $? > /tmp/gauge.status; } | tee /tmp/gauge.log
status=$(cat /tmp/gauge.status)
[ "$status" -eq 0 ] || exit "$status"
grep -Eq '^Scenarios:.*[^0-9]0 skipped' /tmp/gauge.log || {
  echo "conformance: scenarios were skipped (unimplemented steps?)" >&2; exit 1; }
