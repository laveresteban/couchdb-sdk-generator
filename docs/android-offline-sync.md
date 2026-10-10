# Android offline sync SDK: design

Status: core implemented in [couchdb-android](https://github.com/laveresteban/couchdb-android) (see its README for what's left). Builds on `couchdb-openapi` (v0.2.0) and this generator.

## Goal

An Android library (`couchdb-android`) that lets an app read and write
documents with no network, then sync both ways with CouchDB 3.x when it can.
Sync follows the [CouchDB replication protocol](https://docs.couchdb.org/en/stable/replication/protocol.html),
so the server needs nothing custom.

Non-goals for v1: P2P sync between devices, Mango indexes run locally
(simple field indexes only), attachments over 10 MB.

## Layers

```
App
 └─ couchdb-android (hand-written)
     ├─ LocalStore      Room/SQLite: docs, revision tree, local seq
     ├─ Query           Flow-based queries over LocalStore
     ├─ Replicator      push + pull state machines
     ├─ SyncScheduler   WorkManager jobs, connectivity constraints
     └─ RemoteApi       generated Kotlin client (this repo)
```

Only `RemoteApi` is generated. Everything else is hand-written and protected
by `.openapi-generator-ignore`, same as the Python SDK's idiomatic layer.

## Generator changes

Add `config/kotlin.yaml`:

```yaml
generatorName: kotlin
additionalProperties:
  packageName: org.couchdb.client
  library: jvm-retrofit2
  serializationLibrary: kotlinx_serialization
  useCoroutines: true
  dateLibrary: java8
```

Add `kotlin` to `sdk-matrix.json` pointing at `couchdb-android`. Generate
into a `:remote` Gradle module; the sync library depends on it.

Watch for the two spec patterns the README already lists. Untyped `{}` keys
will hit kotlinx-serialization too, so map them to `JsonElement`.

## Spec gaps to close first

Added in spec v0.3.0–v0.5.0 (scenarios in `conformance/specs/sync.spec` and
`changes.spec`). Only `open_revs` is still open; `_bulk_get` covers it:

| Need | Endpoint / param | Why |
|------|------------------|-----|
| Find missing revs | `POST /{db}/_revs_diff` | push: skip revs the server has |
| Fetch many revs | `POST /{db}/_bulk_get` (`revs=true`) | pull in batches |
| Checkpoints | `GET/PUT/DELETE /{db}/_local/{id}` | resume sync |
| Write with history | `_bulk_docs` `new_edits: false` | already in spec, needs a scenario |
| Leaf revs in feed | `_changes` `style=all_docs` | see conflicting branches |
| Revision history | `GET /{db}/{docid}` `revs`, `open_revs`, `latest` | fallback if `_bulk_get` missing |
| Filtered sync | `_changes` `filter`, `doc_ids`, `selector` (POST) | sync a user's subset |
| Long-lived feed | `_changes` `feed=continuous` / `heartbeat` | live sync while app is open |

Model `_revisions` (`{start, ids[]}`) and `_attachments` stubs
(`stub`, `revpos`, `digest`, `follows`) as typed schemas.

## Local storage (Room)

```
docs        (doc_id PK, winning_rev, deleted, local_seq)
revs        (doc_id, rev, parent_rev, deleted, body JSON?, local_seq,
             PK(doc_id, rev))
attachments (digest PK, length, content_type, file_path)
rev_atts    (doc_id, rev, name, digest)
checkpoints (replication_id PK, last_seq, session_id, updated_at)
local_docs  (id PK, body JSON)
```

- Writes append to `revs` and bump a monotonic `local_seq`; the push
  replicator reads changes since its checkpoint from that.
- Winning rev uses CouchDB's rule: non-deleted beats deleted, then longest
  path, then highest rev hash string. Must match the server bit for bit.
- Rev ids: `N-md5(...)`. The exact server hash input isn't something clients
  need to copy; any unique hash works because the server accepts it with
  `new_edits:false`.
- Old non-leaf bodies get compacted (keep ids, drop JSON) after N revs.
- Attachments stored as files under `noBackupFilesDir`, deduped by digest.
- Optional SQLCipher for encryption at rest.

## Replication

Replication id = hash of (local db id, remote URL, filter, direction), like
CouchDB does, so checkpoints survive restarts.

**Pull**
1. Read checkpoint from `_local/<repid>` on both sides; use the lower `last_seq` if they differ.
2. `_changes?style=all_docs&since=<seq>&limit=<batch>`.
3. Check which revs are missing locally.
4. `_bulk_get?revs=true` for the missing ones; insert with full history.
5. Save checkpoint locally and remotely. Repeat until `pending == 0`.

**Push**
1. Local changes since checkpoint.
2. `_revs_diff` with each doc's leaf revs.
3. `_bulk_docs` with `new_edits:false` for missing revs, plus `_revisions`.
4. Attachments: inline base64 under 1 MB, otherwise multipart `PUT`.
5. Checkpoint.

Batch size 100 by default. Retry 5xx and network errors with exponential
backoff; 401 stops sync and reports `AuthRequired`.

## Conflicts

Conflicts are kept, not dropped, same as CouchDB. The SDK picks the same
winner the server would, and exposes losing revs:

```kotlin
interface ConflictResolver {
    suspend fun resolve(docId: String, revs: List<Revision>): Resolution
}
// Resolution.KeepWinner | Resolution.Merge(json) | Resolution.Pick(rev)
```

Default: keep the deterministic winner and leave branches for the app to see.
Resolving writes a new rev on the winner and tombstones the losers, which then
replicates normally.

## Public API (sketch)

```kotlin
val db = CouchLite.open(context, "notes",
    remote = Remote("https://db.example.com/notes", auth = CookieAuth(user, pw)))

db.put(Doc(id = "n1", body = json))          // works offline
db.get("n1")
db.query { where("type" eq "note"); orderBy("updated") }.asFlow()

db.sync.start(mode = SyncMode.Continuous)    // or OneShot / Periodic(15.minutes)
db.sync.state: StateFlow<SyncState>          // Idle, Pulling(n), Pushing(n), Error(e)
db.conflicts(): Flow<List<Conflict>>
```

Auth: cookie (`_session`) with auto-refresh, or a bearer/JWT provider
callback. Credentials stored with EncryptedSharedPreferences.

## Scheduling

- `OneShot` and `Periodic` run in WorkManager with a `CONNECTED` constraint
  (`UNMETERED` optional); periodic minimum is 15 min.
- `Continuous` uses a longpoll/continuous `_changes` loop in a coroutine scope
  tied to the process, falling back to periodic when the app is backgrounded.
- Local writes trigger a debounced push (2 s).

## Testing

- Unit: rev tree, winner selection, rev hashing, against fixtures taken
  from real CouchDB responses.
- Conformance: implement the Gauge steps in Kotlin (`gauge install java`)
  for the remote layer, and add a `sync.spec`:
  offline write then sync, server edit pulled, concurrent edit conflict,
  delete propagates, resume after kill mid-batch, attachment round trip.
- Instrumented tests on an emulator against CouchDB in Docker in CI.
- Interop: sync the same DB with PouchDB in a test to catch protocol drift.

## Prior art to check

Couchbase Lite (different protocol, good API ideas), PouchDB (same protocol,
reference for edge cases), Cloudant Sync Android (archived, closest match).

## Rollout

1. Spec: add the endpoints above + conformance scenarios.
2. Generator: `config/kotlin.yaml`, matrix entry, `couchdb-android` repo.
3. LocalStore + rev tree with unit tests.
4. Pull, then push, then conflicts.
5. WorkManager scheduling, then attachments.
6. Sample app (notes) that works in airplane mode.
