# Node.js / TypeScript SDK — design

Date: 2026-10-09
Status: approved for planning

## Goal

Add `couchdb-node`, a second generated SDK (after `couchdb-python`) at full
parity: a generated client plus a hand-written ergonomic wrapper, unit +
integration tests, and the shared Gauge conformance suite. Decisions:

- Generator: `typescript-fetch` (Node 18+ built-in `fetch`, zero runtime deps).
- Repo / npm package name: `couchdb-node`.
- Module format: CommonJS (`tsc`-only build).
- Test runner: vitest.
- Conformance: all 11 specs implemented in this pass.

The one unavoidable divergence from the Python SDK: `typescript-fetch` is
Promise-based, so the entire wrapper is **async**. Python's dict-style sugar
(`db["id"]`, `id in db`, `del db[id]`) has no JS equivalent and becomes explicit
methods. Method names are idiomatic camelCase.

## Repo layout (`couchdb-node/`)

New git repo in the workspace, sibling to `couchdb-python`.

```
couchdb-node/
  couchdb_client/        generated (typescript-fetch); committed
    apis/ models/ runtime.ts index.ts .openapi-generator/ .openapi-generator-ignore
  src/                   hand-written wrapper (mirrors couchdb_sdk/)
    index.ts   client.ts   database.ts   changes.ts   errors.ts
  tests/
    unit.test.ts            # backoff/isTransient/retry, mocked
    integration.test.ts     # generated client against live CouchDB
    sdk.integration.test.ts # wrapper against live CouchDB
  conformance/
    manifest.json           # { "Language": "js" }
    env/default/            # default.properties, js.properties
    step_impl/steps.ts      # all 11 specs
  scripts/conformance.sh     # copies shared specs, runs gauge
  dist/                      # tsc output (gitignored)
  package.json  tsconfig.json  vitest.config.ts
  .gitignore  README.md  LICENSE  NOTICE  CHANGELOG.md
  .generated-from            # written by generate.sh
```

The generator writes only into `couchdb_client/` (invoked with
`-o ../couchdb-node/couchdb_client`), so every hand-written file is a sibling —
no root-level `.openapi-generator-ignore` juggling. The generated client is
committed so the repo is usable without regenerating (mirrors Python).

## Generator wiring (`couchdb-sdk-generator/`)

- `config/typescript.yaml`:
  ```yaml
  generatorName: typescript-fetch
  templateDir: templates/typescript
  additionalProperties:
    npmName: couchdb-node
    supportsES6: true
    generateSourceCodeOnly: true   # no package.json/tsconfig from the generator
    withoutRuntimeChecks: false
  globalProperties:
    apiDocs: true
    modelDocs: true
  ```
- `templates/typescript/README.md`: optional mirror of the Python template.
- `sdk-matrix.yaml`: add
  ```yaml
    typescript:
      generator: typescript
      config: config/typescript.yaml
      repo: couchdb-node
  ```
- `package.json`: add
  `"generate:node": "bash scripts/generate.sh typescript ../couchdb-openapi/openapi.yaml ../couchdb-node/couchdb_client"`.
- `generate.sh` is unchanged (already language-generic). It passes
  `packageVersion`, which `typescript-fetch` ignores; with
  `generateSourceCodeOnly` the generated layer has no `package.json` anyway.

### Versioning

Lockstep with the spec's `info.version` is enforced at the hand-written
`package.json`: its `version` must equal `info.version`. The release step sets
it (same discipline as Python). `generate.sh` still records provenance in
`couchdb_client/.generated-from`.

## Wrapper modules (1:1 with `couchdb_sdk/`)

All methods are `async` and return `Promise`.

### `errors.ts`
- `CouchDBError` base (`status`, `error`, `reason`, `headers`) and subclasses
  `Unauthorized` (401), `Forbidden` (403), `NotFound` (404), `Conflict` (409),
  `PreconditionFailed` (412), keyed by status.
- `translate(fn)`: runs an async thunk, catches the generated runtime's
  `ResponseError`/`FetchError`, reads `response.status` and JSON `{error, reason}`,
  rethrows the typed error carrying `response.headers` (for `Retry-After`).
  (Replaces Python's `contextlib` `translate()` context manager.)

### `client.ts` — `CouchDB`
- Construct with `url`, optional `username`/`password`. Basic auth via the
  generated `Configuration.username/password`.
- Cookie sessions: a stored cookie string injected by a fetch **middleware**
  (`pre` hook adds `Cookie`); `login` reads `Set-Cookie` from the `_session`
  response (`getSetCookie()` / `set-cookie` header), `logout` clears it.
- Methods: `info`, `up`, `uuids`, `allDbs`, `login`, `logout`, `session`,
  `createDatabase`, `deleteDatabase`, `database(name)` (replaces `__getitem__`),
  `replicate(source, target, options?)` (bare names resolved to local db URLs
  carrying credentials, as in Python).

### `database.ts` — `Database`, `Partition`
- Documents: `get`, `save` (create/update; mutates and returns the doc with
  `_id`/`_rev`), `remove(docOrId)`, `update(id, fn, retries=5)` (conflict-retry),
  `bulkSave`, `has(id)`.
- Queries: `allDocs`, `find(selector, opts?)` → `FindResult`, `createIndex`,
  `indexes`.
- Design/views: `design`, `saveDesign`, `deleteDesign`, `view`.
- Attachments: `putAttachment(id, name, data, contentType?)` → new rev,
  `getAttachment` → `Uint8Array`, `deleteAttachment` → new rev. (`data` accepts
  `Uint8Array`/`Blob`.)
- Changes: `changes(opts?)` → `ChangesResult` (`doc_ids`/`selector` filter
  server-side via `POST _changes`), `follow(opts?)` → `ChangesFeed`.
- Local docs: `getLocal`, `putLocal`.
- Security: `security`, `setSecurity(admins?, members?)`.
- Partitions: `partition(name)` → `Partition` with `allDocs`, `find`.
- `FindResult` (`docs`, `bookmark?`, `warning?`) and `ChangesResult`
  (`results`, `lastSeq`, `pending?`) as exported types.

### `changes.ts` — `ChangesFeed`
- Implements `AsyncIterable<Change>`; consumed with `for await`.
- Longpoll (`feed=longpoll`, `timeout`, `limit=batchSize`); read timeout outlasts
  the server longpoll timeout.
- `isTransient(err)`: network errors, 429, 5xx.
- `retryAfter(err)`: seconds from `Retry-After` header if present.
- Jittered exponential backoff capped at `maxBackoff` (default 30s),
  optional `maxRetries`.
- `checkpoint`: position stored in `_local/<checkpoint>` after each consumed
  batch (at-least-once); a restarted reader resumes.
- `stop()`: ends iteration after the current poll.

### `src/index.ts`
Re-exports `CouchDB`, `Database`, `Partition`, `ChangesFeed`, `FindResult`,
`ChangesResult`, and all error classes.

## Tests (vitest)

- `unit.test.ts`: `isTransient`, `retryAfter`, backoff timing and max-retry
  behavior with a mocked poll — mirrors Python's `test_sdk_unit.py`.
- `integration.test.ts` / `sdk.integration.test.ts`: against a live CouchDB at
  `COUCHDB_URL` (default `http://localhost:5984`, admin/password). Skipped when
  the server is unreachable (a `beforeAll` probe), mirroring Python's `conftest`.
- `package.json` scripts: `test` (vitest run), `build` (tsc), `conformance`.

## Conformance

- `gauge install js`; `manifest.json` → `{ "Language": "js" }`;
  `env/default/js.properties` points Gauge at `step_impl` and uses `ts-node`/
  compiled JS as the runner needs.
- `step_impl/steps.ts` reimplements the steps for all 11 specs
  (server, authentication, databases, documents, query, views, attachments,
  changes, security, partitions, replication), with an `afterScenario` hook that
  drops any databases a scenario created.
- `scripts/conformance.sh` adapted from Python's: resolves
  `CONFORMANCE_SPECS` (default `../couchdb-sdk-generator/conformance/specs`),
  copies into gitignored `conformance/specs`, runs `gauge run specs`.
- Shared spec files are unchanged; no new scenarios are added in this pass, so
  no copy back to the generator repo is required. If Gauge cannot run locally,
  conformance is reported as unverified (as with the Python changes-feed work).

## Build & publish

- `tsconfig.json`: `module: commonjs`, `target: es2020`, `declaration: true`,
  `outDir: dist`, includes `src` and `couchdb_client`.
- `package.json`: `main: dist/src/index.js`, `types: dist/src/index.d.ts`,
  `engines.node >=18`, no runtime deps, `files: ["dist"]`, `version` tracking
  the spec.
- `.gitignore`: `dist/`, `node_modules/`, `conformance/specs`,
  `conformance/reports`, `conformance/logs`.
- `README.md`, `LICENSE`, `NOTICE`, `CHANGELOG.md` mirror Python's.

## Out of scope

- Dual ESM+CJS / browser build (Approach B) — later if needed.
- New conformance scenarios or spec changes.
- CI workflow wiring beyond mirroring Python's job (can follow once green).
```