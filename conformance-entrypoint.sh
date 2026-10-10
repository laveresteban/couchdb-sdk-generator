#!/bin/sh
# Stage the mounted python SDK's conformance project, point it at the CouchDB
# service, wait for the server, then run Gauge. Extra args go to `gauge run`,
# e.g. `docker compose run --rm gauge --tags changes`.
set -e
: "${COUCHDB_URL:=http://couchdb:5984}"
cp -r /sdk/conformance/. /work
sed -i "s#^COUCHDB_URL = .*#COUCHDB_URL = ${COUCHDB_URL}#" env/default/*.properties
export PYTHONPATH=/sdk

echo "waiting for CouchDB at ${COUCHDB_URL} ..."
python3 - "$COUCHDB_URL" <<'PY'
import sys, time, urllib.request
url = sys.argv[1].rstrip("/") + "/_up"
for _ in range(60):
    try:
        urllib.request.urlopen(url, timeout=2)
        print("CouchDB is up")
        break
    except Exception:
        time.sleep(1)
else:
    sys.exit("CouchDB did not become ready")
PY

exec gauge run specs "$@"
