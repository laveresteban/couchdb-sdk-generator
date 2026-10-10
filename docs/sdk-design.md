# Shared SDK design

How the hand-written layer of every CouchDB SDK behaves, so the SDKs stay
alike. The generated client follows the spec; this page covers everything
on top of it. The conformance specs test the parts a server can observe.
This page also covers the parts it can't, like retry timing and checkpoint
batching.

When an SDK changes one of these behaviors, change it here and in the other
SDKs too, or note the difference in the table at the end.

## Layout

| | couchdb-python | couchdb-node | couchdb-android |
|---|---|---|---|
| Generated client | `couchdb_client/` | `couchdb_client/` | none (see generator README) |
| Hand-written layer | `couchdb_sdk/` | `src/` | `sync-core/`, `android/` |
| Conformance steps | `conformance/step_impl/steps.py` | `conformance/step_impl/steps.ts` | `conformance/` (Kotlin) |
| CI | calls `sdk-ci.yml` from this repo | calls `sdk-ci.yml` from this repo | own `ci.yml` (Gradle) |

## Versioning

- An SDK's version is the spec's `info.version`, stamped by `generate.sh`.
- `.generated-from` records the spec commit, the generator commit and the
  OpenAPI Generator version. The `generated` job in `sdk-ci.yml`
  regenerates from those commits and fails if the result differs from
  what's committed.
- Release workflows refuse to publish when the tag, the package version
  and `spec_version` disagree.

## Errors

Non-2xx responses become typed errors carrying `status`, `error`, `reason`
(from CouchDB's JSON body, or the raw text) and the response `headers`.

| Status | Python | Node | Android |
|---|---|---|---|
| 401 | `Unauthorized` | `Unauthorized` | `AuthRequiredException` |
| 403 | `Forbidden` | `Forbidden` | `CouchException` |
| 404 | `NotFound` (also a `KeyError`) | `NotFound` | `null` from `getLocal`/`request`, else `CouchException` |
| 409 | `Conflict` | `Conflict` | `CouchException` / `ConflictException` (local) |
| 412 | `PreconditionFailed` | `PreconditionFailed` | `CouchException` |
| other | `CouchDBError` | `CouchDBError` | `CouchException` |
| network | `CouchDBError(status=0)` or urllib3 error | `CouchDBError(status=0)` | `IOException` |

A 304 from a conditional read isn't an error to callers: `get_if_changed`
and `getIfChanged` return null/None.

## Retries

Only these are retried: network errors (connection reset, timeout,
refused), 429, and 5xx. Everything else (bad URL, 4xx) fails immediately,
because retrying won't help.

- Delay: `Retry-After` if the server sent it, otherwise a jittered
  exponential backoff, `random(0.5, 1.0) * 2^attempt` seconds, capped at
  `max_backoff` (30 s).
- `max_retries` is unlimited by default for long-running readers.
- Android's live sync and `SyncWorker` follow the same rule: transient
  errors retry, 401 and other 4xx stop sync and surface the error.

## Changes feed reader (`follow`, `ChangesFeed`)

- Two modes:
  - `longpoll` (the default) polls one batch at a time.
  - `continuous` holds one streaming connection open and reads the
    newline-delimited JSON itself, because generated clients can't stream it.
- Heartbeats (blank lines) keep the connection alive. The read timeout is
  the heartbeat plus a margin, so a silent connection counts as dead and
  the reader reconnects from the last seq it saw.
- Rows with `"seq": null` (from `seq_interval`) don't move the position.
- `doc_ids`/`selector` filters are sent as a POST body, in both modes.
- Checkpoints:
  - Stored in `_local/<checkpoint>` as `{"since": "<seq>"}`.
  - Longpoll saves after each batch. Continuous saves every `batch_size`
    rows, when the server ends the stream, and on `stop()`.
  - The reader reuses the `_rev` from its last save, so a save is one PUT
    rather than a GET plus a PUT.
- Delivery is at least once: rows since the last save can repeat after a
  crash.
- `stop()` ends iteration right away. Node and Android also abort the
  open request; Python returns at the next row or poll.

## Sessions

- `login(name, password)` starts a cookie session. Every response that
  carries a fresh `AuthSession` cookie replaces the stored one, since
  CouchDB renews it as it nears expiry.
- If a request sent with a cookie gets a 401, the client logs in again
  once and retries that request. Android makes concurrent requests share a
  single login; Python and Node log in once per request that got the 401.
- `logout()` forgets the credentials, so nothing logs back in.

## Documents and bulk writes

- `save(doc)` creates or updates and sets `_id`/`_rev` on the doc passed in.
- `bulk_save(docs)` sets `_id`/`_rev` on every doc that was saved and
  returns per-doc results, failures included.
- `bulk_save(docs, new_edits=False)` writes revisions as given (the
  replicator's write path). CouchDB then reports only failures.
- `update(id, fn, retries=5)` re-reads and retries on 409.
- Generated document models never touch user JSON on the way out: Node
  sends the user's object verbatim, and Python sets only the keys present.

## Replication helpers

- `replicate(source, target)`: a bare database name resolves to
  `replication_url/<name>` with the client's credentials. `replication_url`
  defaults to the client URL; set it when the server sees itself under
  another hostname. Full URLs are passed through as plain strings.
- Building blocks: `revs_diff`, `bulk_get(revs=…)`,
  `bulk_save(new_edits=False)`, and `get/put/delete_local`.

## API parity

Node uses camelCase; Python and Android use their own conventions.
"—" means not offered.

| Area | Python | Node | Android (`sync-core`) |
|---|---|---|---|
| Server | `info`, `up`, `uuids`, `all_dbs`, `active_tasks`, `dbs_info`, `scheduler_jobs`, `scheduler_docs`, `db_updates` | same, camelCase | — |
| Sessions | `login`, `logout`, `session` | same | `Auth.Session` (automatic) |
| Databases | `create_database`, `delete_database`, `info`, `exists` | `createDatabase`, `deleteDatabase`, `info`, `exists` | `RemoteDb.ensureExists`, `destroy` |
| Documents | `get`, `head`, `get_if_changed`, `save`, `delete`, `update`, `bulk_save`, dict access | `get`, `head`, `getIfChanged`, `save`, `remove`, `update`, `bulkSave`, `has` | local store: `get`, `put`, `delete` |
| Queries | `all_docs`, `find`, `explain`, `create_index`, `indexes`, `design_docs`, `local_docs` | same, camelCase | local Mango: `find`, `observe`, `createIndex` |
| Views | `design`, `save_design`, `delete_design`, `view` | same, camelCase | — |
| Attachments | `put_attachment`, `get_attachment`, `delete_attachment` | same, camelCase | local: `putAttachment`, `getAttachment`, `deleteAttachment` |
| Changes | `changes`, `follow` | `changes`, `follow`, `continuousChanges` | `ChangesFeed`, `RemoteDb.changes` |
| Replication | `replicate`, `revs_diff`, `bulk_get`, `get/put/delete_local` | same, camelCase | `Replicator` (full two-way sync) |
| Maintenance | `compact`, `view_cleanup`, `purge` | same, camelCase | local `compact` |
| Security | `security`, `set_security` | same, camelCase | — |
| Partitions | `partition(name).all_docs/find` | same | — |

Known differences:
- Python is synchronous, so its `stop()` can't abort an in-flight longpoll.
- Android is an offline-first store, not a remote client. It covers the
  replication protocol and leaves admin endpoints out.
