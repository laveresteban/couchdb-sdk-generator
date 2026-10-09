# CouchDB SDK conformance suite

Language-agnostic acceptance tests, written as [Gauge](https://gauge.org)
specifications. Every SDK runs these same scenarios against a real CouchDB,
so behavior stays consistent across languages.

```
conformance/specs/*.spec   ← this repo: WHAT every SDK must do (plain markdown)
couchdb-<lang>/conformance/step_impl/   ← each SDK repo: HOW, in that language
```

## Areas covered

| Spec | Tag | Scenarios |
|------|-----|-----------|
| server.spec | `server` | anonymous server info, `_up`, bulk UUIDs |
| authentication.spec | `auth` | cookie login/logout, bad password → 401 |
| databases.spec | `databases` | create/inspect/delete, duplicate → 412 |
| documents.spec | `documents` | CRUD, stale rev → 409, server ids, bulk writes |
| query.spec | `query` | Mango find, indexes + sort, bookmark pagination |
| views.spec | `views` | design docs, map/reduce, delete |
| attachments.spec | `attachments` | upload, download, delete |
| changes.spec | `changes` | normal feed, resume from seq, deletions |
| security.spec | `security` | members → anonymous 401 |
| partitions.spec | `partitions` | partitioned all_docs and find |
| replication.spec | `replication` | one-off replication |
| sync.spec | `sync` | `_revs_diff`, `_bulk_get`, `_local` docs, `new_edits:false`, conflicts, `style=all_docs`, filtered changes |

## Writing new scenarios (TDD)

1. Add or extend a `.spec` here first. Keep step text about **behavior**, not
   any language's API (say "Save document", not "call db.put()").
2. Run the suite in an SDK repo: new steps show as *skipped* with generated
   stubs, so the suite is red.
3. Implement the steps (and any missing SDK feature) until it is green.
4. Merge the spec change here, then the SDK change.

Conventions:
- Every parameter is a quoted string; steps convert numbers themselves.
- The context step at the top of a spec (e.g. `* Connect as admin`) runs before each scenario.
- Steps must clean up any databases they create (Python: an `after_scenario` hook).
- Server: CouchDB 3.x at `COUCHDB_URL` (default `http://localhost:5984`),
  admin `COUCHDB_USER` / `COUCHDB_PASSWORD` (default `admin` / `password`).

## Adding a language

1. In `couchdb-<lang>`, create a Gauge project in `conformance/`
   (`manifest.json`, `env/default/`, `step_impl/`) for that language's runner
   (`gauge install java|js|dotnet|ruby|go`).
2. Copy `couchdb-python/scripts/conformance.sh`. It copies these specs into
   `conformance/specs` (gitignored) and runs `gauge run specs`.
3. Implement steps until `gauge run` shows 0 skipped, 0 failed.
4. Add the `conformance` CI job (see `couchdb-python/.github/workflows/ci.yml`).
