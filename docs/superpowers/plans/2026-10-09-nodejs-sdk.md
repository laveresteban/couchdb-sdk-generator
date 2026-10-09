# couchdb-node (TypeScript SDK) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `couchdb-node`, a TypeScript CouchDB SDK at full parity with `couchdb-python` — generated client + ergonomic wrapper + vitest tests + the shared Gauge conformance suite, all runnable locally via Docker.

**Architecture:** `couchdb-sdk-generator` gains a `typescript` target (`typescript-fetch`) that emits the client into `couchdb-node/couchdb_client/`. A hand-written async wrapper in `couchdb-node/src/` mirrors `couchdb_sdk/` one-to-one. The whole wrapper is Promise-based; `follow()` is an `AsyncIterable`; Python's dict sugar becomes explicit methods. Version is derived from the spec via `.generated-from`.

**Tech Stack:** TypeScript (CommonJS, Node ≥18 built-in `fetch`), `@openapitools/openapi-generator-cli` (`typescript-fetch`), vitest, `@getgauge/cli` + `js` plugin, Docker Compose (CouchDB 3).

**Spec:** `couchdb-sdk-generator/docs/superpowers/specs/2026-10-09-nodejs-sdk-design.md`

## Global Constraints

- Node ≥18 (built-in `fetch`); zero runtime dependencies in the published package.
- Module format: CommonJS. Build is `tsc`-only → `dist/`.
- npm package + repo name: `couchdb-node`.
- Published `version` must equal the spec's `info.version` (currently `0.3.0`), stamped from `couchdb_client/.generated-from`; never hand-edited.
- Generated client lives in `couchdb_client/` and is committed; `src/`, `tests/`, `conformance/`, `scripts/` are hand-written and must never be overwritten by the generator.
- **Generated layout (actual, from Task 1):** sources are under `couchdb_client/src/` — `couchdb_client/src/index.ts` re-exports `Configuration`, `ResponseError`, and the 11 API classes. The hand-written wrapper imports generated symbols from `../couchdb_client/src`. The generator also emits `couchdb_client/{package.json,tsconfig.json,tsconfig.esm.json,README.md,.npmignore,.gitignore,.openapi-generator-ignore}`; leave them (harmless in a subdir, unpublished).
- Wrapper public API mirrors `couchdb_sdk` semantics; method names are idiomatic camelCase.
- CouchDB target: `COUCHDB_URL` (default `http://localhost:5984`), `COUCHDB_USER`/`COUCHDB_PASSWORD` (default `admin`/`password`).
- `generate.sh` and the shared `conformance/specs/*.spec` are NOT modified by this plan.
- Commits land in the repo that owns the file: generator-config changes → `couchdb-sdk-generator`; everything else → `couchdb-node`.

## Review Focus

- **Network failure mid-`follow()`** (server unreachable / `TypeError` from `fetch`): expected transient → retried with backoff, not a crash. Test in Task 4.
- **Non-JSON error body** (HTML/plain from a proxy): expected `reason` keeps the raw text, status still typed. Test in Task 3.
- **Binary attachment round-trip** (non-UTF-8 bytes): expected bytes return byte-identical, not corrupted by text decoding. Test in Task 5.
- **Login with wrong password** (no `Set-Cookie` returned): expected typed `Unauthorized` (status 401), cookie unchanged. Test in Task 6.
- **Stale-rev save** (`_rev` not current): expected typed `Conflict` (409). Test in Task 5.

---

## Task 1: Generator target + generated client

**Files:**
- Create: `couchdb-sdk-generator/config/typescript.yaml`
- Create: `couchdb-sdk-generator/templates/typescript/README.md`
- Modify: `couchdb-sdk-generator/sdk-matrix.yaml`
- Modify: `couchdb-sdk-generator/package.json` (add `generate:node` script)
- Generated (committed): `couchdb-node/couchdb_client/**`

**Interfaces:**
- Produces: a generated `couchdb_client` module whose `index.ts` re-exports `Configuration`, a `ResponseError` runtime class, and API classes `ServerApi`, `AuthenticationApi`, `DatabasesApi`, `DocumentsApi`, `QueryApi`, `DesignDocumentsApi`, `AttachmentsApi`, `ChangesApi`, `SecurityApi`, `PartitionsApi`, `ReplicationApi`. Operation methods are the camelCase of the Python client's snake_case ops (e.g. `getServerInformation`, `putDatabase`, `postFind`, `postChanges`, `putAttachment`). The wrapper tasks map to these, verifying exact names against the emitted `apis/`.

- [ ] **Step 1: Write `config/typescript.yaml`**

```yaml
generatorName: typescript-fetch
templateDir: templates/typescript
additionalProperties:
  npmName: couchdb-node
  supportsES6: true
  generateSourceCodeOnly: true
  withoutRuntimeChecks: false
globalProperties:
  apiDocs: true
  modelDocs: true
```

- [ ] **Step 2: Add the `typescript` entry to `sdk-matrix.yaml`** under `languages:` — `generator: typescript`, `config: config/typescript.yaml`, `repo: couchdb-node`.

- [ ] **Step 3: Add the `generate:node` script to `package.json`**

Value: `bash scripts/generate.sh typescript ../couchdb-openapi/openapi.yaml ../couchdb-node/couchdb_client && node ../couchdb-node/scripts/sync-version.mjs` (the sync step is created in Task 2; until then it may no-op — run the generator alone for this task's verification).

- [ ] **Step 4: Create `templates/typescript/README.md`** mirroring `templates/python/README.md` (short generated-client note).

- [ ] **Step 5: Generate the client** — `bash scripts/generate.sh typescript ../couchdb-openapi/openapi.yaml ../couchdb-node/couchdb_client`.
Expected: `couchdb-node/couchdb_client/{index.ts,runtime.ts,apis/,models/}` and `couchdb_client/.generated-from` with `spec_version=0.3.0`.

- [ ] **Step 6: Verify the generated client typechecks** — from `couchdb-node/`, `npx -y typescript@5 tsc --noEmit --strict couchdb_client/index.ts` (or the Task 2 tsconfig once present).
Expected: no type errors.

- [ ] **Step 7: Commit** — generator-config changes to `couchdb-sdk-generator`; the generated `couchdb_client/` is committed in Task 2 with the rest of the repo scaffold.

```bash
git -C ../couchdb-sdk-generator add config/typescript.yaml templates/typescript sdk-matrix.yaml package.json
git -C ../couchdb-sdk-generator commit -m "feat: add typescript (node) generator target"
```

---

## Task 2: couchdb-node package scaffold + version automation

**Files:**
- Create: `couchdb-node/package.json`, `tsconfig.json`, `vitest.config.ts`, `.gitignore`
- Create: `couchdb-node/scripts/sync-version.mjs`
- Create: `couchdb-node/{README.md,LICENSE,NOTICE,CHANGELOG.md}`
- Create: `couchdb-node/tests/sync-version.test.ts`

**Interfaces:**
- Consumes: `couchdb_client/.generated-from` (`spec_version=…`) from Task 1.
- Produces: a buildable package. `npm run build` → `dist/`; `npm test` runs vitest; `node scripts/sync-version.mjs` stamps `package.json.version`; `node scripts/sync-version.mjs --check` exits non-zero on drift.

- [ ] **Step 1: `git init` in `couchdb-node/`** and copy `LICENSE`/`NOTICE` verbatim from `couchdb-python`.

- [ ] **Step 2: Write the failing test** `tests/sync-version.test.ts`:

```ts
// Writes a temp .generated-from and package.json, runs syncVersion(), asserts version copied; --check throws on mismatch.
import { readVersion, writeVersion } from "../scripts/sync-version.mjs";
test("stamps package version from .generated-from", () => {
  expect(readVersion("spec_version=0.3.0\n")).toBe("0.3.0");
});
```

- [ ] **Step 3: Run it to verify it fails** — `npx vitest run tests/sync-version.test.ts`. Expected: FAIL (module missing).

- [ ] **Step 4: Write `scripts/sync-version.mjs`** exporting `readVersion(text: string): string` (parse `spec_version=`) and a CLI: default stamps `package.json.version` from `couchdb_client/.generated-from`; with `--check`, exits 1 and prints a diff message if they differ.

- [ ] **Step 5: Write `package.json`** — name `couchdb-node`, `version` `0.3.0`, `main` `dist/src/index.js`, `types` `dist/src/index.d.ts`, `files` `["dist"]`, `engines.node` `>=18`, no `dependencies`; `devDependencies`: `typescript`, `vitest`, `@getgauge/cli`; scripts: `build` (`tsc`), `test` (`vitest run`), `conformance` (`bash scripts/conformance.sh`), `prepublishOnly` (`node scripts/sync-version.mjs --check && npm run build`). Write `tsconfig.json` (`module commonjs`, `target es2020`, `declaration true`, `outDir dist`, `rootDir "."`, `strict true`, `skipLibCheck true`, include `src` + `couchdb_client/src` — NOT `couchdb_client` root, to skip the generator's own tsconfig/package.json), `vitest.config.ts`, and `.gitignore` (`dist/ node_modules/ conformance/specs conformance/reports conformance/logs`). Resulting build layout: `dist/src/index.js` + `dist/couchdb_client/src/…`, so `main`=`dist/src/index.js`.

- [ ] **Step 6: Run tests + build** — `npm install`, `npx vitest run tests/sync-version.test.ts` (PASS), `node scripts/sync-version.mjs` then confirm `package.json` version is `0.3.0`, `npm run build` (emits `dist/`).

- [ ] **Step 7: Write `README.md`** (install, quickstart, parity note) and `CHANGELOG.md` (mirror Python's format, `0.3.0`).

- [ ] **Step 8: Commit** (couchdb-node) — scaffold + generated `couchdb_client/`.

```bash
git add -A && git commit -m "chore: scaffold couchdb-node package + version sync"
```

---

## Task 3: errors.ts + shared types

**Files:**
- Create: `couchdb-node/src/errors.ts`
- Create: `couchdb-node/src/types.ts`
- Create: `couchdb-node/tests/errors.test.ts`

**Interfaces:**
- Produces (`types.ts`): `type Doc = Record<string, any>`; `interface Change { id:string; seq?:string; deleted?:boolean; doc?:any; changes?:any[] }`; `interface FindResult { docs: Doc[]; bookmark?: string; warning?: string }`; `interface ChangesResult { results: Change[]; lastSeq: string; pending?: number }`.
- Produces (`errors.ts`): `class CouchDBError extends Error { status:number; error:string; reason:string; headers:Record<string,string> }`; subclasses `Unauthorized`(401) `Forbidden`(403) `NotFound`(404) `Conflict`(409) `PreconditionFailed`(412); `fromResponse(res: Response): Promise<CouchDBError>`; `translate<T>(fn: () => Promise<T>): Promise<T>` which catches the generated `ResponseError` (`err.response: Response`) and network `TypeError`, converting to a typed error (network → status 0).

- [ ] **Step 1: Write the failing tests** `tests/errors.test.ts` (mirror `test_sdk_unit.py` error cases):
  - status→class table (401/403/404/409/412 → subclass, 500 → `CouchDBError`), asserting `{status,error,reason}`.
  - non-JSON body (`"<html>oops</html>"`, status 500) keeps `oops` in `reason`.
  - `headers` carried through (`Retry-After: "3"`).
  - `translate(async () => { throw makeResponseError(409) })` rejects with `Conflict`.
  - Build fixtures with `new Response(body, { status, headers })` and a fake `{ name:"ResponseError", response }`.

- [ ] **Step 2: Run to verify they fail** — `npx vitest run tests/errors.test.ts`. Expected: FAIL.

- [ ] **Step 3: Implement `src/errors.ts` and `src/types.ts`** per the Interfaces block. `fromResponse` reads `res.status`, tries `res.json()` for `{error,reason}`, falls back to `res.text()` as `reason`, copies headers.

- [ ] **Step 4: Run to verify they pass** — `npx vitest run tests/errors.test.ts`. Expected: PASS.

- [ ] **Step 5: Commit** — `git add src/errors.ts src/types.ts tests/errors.test.ts && git commit -m "feat: typed errors + shared types"`.

---

## Task 4: changes.ts (ChangesFeed)

**Files:**
- Create: `couchdb-node/src/changes.ts`
- Create: `couchdb-node/tests/changes.unit.test.ts`

**Interfaces:**
- Consumes: `Doc`, `Change`, `ChangesResult` (Task 3 `types.ts`); `CouchDBError`/`NotFound` (Task 3).
- Produces: `interface ChangesSource { changes(opts?:any): Promise<ChangesResult>; getLocal(id:string): Promise<Doc>; putLocal(id:string, doc:Doc): Promise<Doc> }` (the structural slice `ChangesFeed` needs — `Database` satisfies it, so no import of `Database`, breaking the cycle); `isTransient(err:unknown):boolean` (network/`TypeError`, 429, ≥500); `retryAfter(err:unknown):number|undefined`; `class ChangesFeed implements AsyncIterable<Change>` with `constructor(db: ChangesSource, opts?: { since?="0"; checkpoint?; timeout?=60000; batchSize?=500; maxRetries?; maxBackoff?=30; sleep?; [param]:any })`, `stop()`, and `[Symbol.asyncIterator]()`. `sleep(ms)` is injectable (default real) so tests assert delays. Longpoll read timeout outlasts the server `timeout`.

- [ ] **Step 1: Write failing unit tests** `tests/changes.unit.test.ts` (mirror the Python changes-feed unit tests, with an injected `sleep` spy over a mock `ChangesSource`):
  - retries a transient 503 then yields the row, then a fatal `NotFound` rejects; `feed.since === "1"`; first backoff delay in `[0.5,1.0]`s.
  - gives up after `maxRetries=2` → 3 calls, rejects `CouchDBError`.
  - honors `Retry-After: "7"` → `sleep` called once with `7000`ms.
  - **network error (`new TypeError("fetch failed")`) is transient** → retried, not thrown (Review Focus).

- [ ] **Step 2: Run to verify they fail** — `npx vitest run tests/changes.unit.test.ts`. Expected: FAIL.

- [ ] **Step 3: Implement `src/changes.ts`** per Interfaces. Backoff: `retryAfter(err) ?? rand(0.5,1.0)*2**attempt`, capped at `maxBackoff`, via `await this.sleep(ms*1000)`. On `checkpoint`: load `_local/<checkpoint>` `since` before iterating; after each consumed batch where `lastSeq` advanced, write it back (at-least-once).

- [ ] **Step 4: Run to verify they pass** — `npx vitest run tests/changes.unit.test.ts`. Expected: PASS.

- [ ] **Step 5: Commit** — `git add src/changes.ts tests/changes.unit.test.ts && git commit -m "feat: ChangesFeed longpoll + backoff + checkpoint"`.

---

## Task 5: database.ts (Database, Partition)

**Files:**
- Create: `couchdb-node/src/database.ts`
- Create: `couchdb-node/tests/database.integration.test.ts`
- Create: `couchdb-node/tests/database.unit.test.ts`
- Create: `couchdb-node/tests/helpers.ts` (shared `URL/USER/PASSWORD`, `uniqueName()`, `serverUp()` probe for skip-gating; reused by Task 6)

**Interfaces:**
- Consumes: `translate`, `Doc`/`FindResult`/`ChangesResult`/`Change` (Task 3); `ChangesFeed`/`ChangesSource` (Task 4); the generated `Configuration` + `DatabasesApi/DocumentsApi/QueryApi/DesignDocumentsApi/AttachmentsApi/ChangesApi/SecurityApi/PartitionsApi`.
- Produces: `class Database { constructor(config: Configuration, name: string); name: string; ... }` (satisfies `ChangesSource`) and `class Partition { allDocs(query?); find(selector, opts?) }`. Methods (all async except `follow`/`partition`): `info`, `exists`, `get(docid,params?)`, `save(doc)` (mutates+returns `_id`/`_rev`; no `_id` → POST, else PUT), `remove(docOrId)`, `update(docid, fn, retries=5)` (retry on `Conflict`), `bulkSave(docs)`, `has(docid)`, `allDocs(query?)`, `find(selector, opts?)`, `createIndex(fields, name?, opts?)`, `indexes()`, `design(name)`, `saveDesign(name, views, extra?)`, `deleteDesign(name)`, `view(ddoc, view, query?)`, `putAttachment(docid,name,data:Uint8Array|Blob,contentType="application/octet-stream")`, `getAttachment(docid,name):Promise<Uint8Array>`, `deleteAttachment(docid,name)`, `changes(opts?)`, `follow(opts?):ChangesFeed`, `getLocal(docid)`, `putLocal(docid,doc)`, `security()`, `setSecurity(admins?,members?)`, `partition(name):Partition`.
- Note: `changes(opts)` sends `POST _changes` with `filter` defaulting to `_doc_ids`/`_selector` when `docIds`/`selector` is given, else `GET _changes` (mirror Python `changes`).

- [ ] **Step 1: Write failing unit test** `tests/database.unit.test.ts` — `update()` retries on `Conflict` then succeeds (incremented doc saved), and gives up after `retries` (mirror `test_update_*`). Use a `Database` with `get`/`save` stubbed (vitest `vi.spyOn`), no server.

- [ ] **Step 2: Write failing integration tests** `tests/database.integration.test.ts` (skip-gated), covering parity with `test_sdk_integration.py` and the Review Focus:
  - save tracks revisions (`1-`→`2-`); get/remove; `has`.
  - **stale-rev save → `Conflict`** (Review Focus).
  - create-without-id read back; `bulkSave` all ok; `allDocs` count.
  - find `$gt`, sorted desc, index listed, bookmark pagination.
  - design/view map+reduce, delete design → `design()` rejects `NotFound`.
  - attachments: text round-trip; **binary (`Uint8Array([0,1,2,255])`) round-trip byte-identical** (Review Focus); listed in `_attachments`; delete.
  - security set members / read back; local docs put/get; partition all_docs + find (needs a partitioned db).

- [ ] **Step 3: Run to verify they fail** — `npx vitest run tests/database.*.test.ts`. Expected: FAIL.

- [ ] **Step 4: Implement `src/database.ts`** per Interfaces. Map each method to the generated API call, verifying operation names/param-object shapes against `couchdb_client/apis/`. `getAttachment` converts the returned `Blob`/bytes to `Uint8Array` without text decoding.

- [ ] **Step 5: Run to verify they pass** — `npx vitest run tests/database.*.test.ts`. Expected: PASS.

- [ ] **Step 6: Commit** — `git add src/database.ts tests/database.*.test.ts tests/helpers.ts && git commit -m "feat: Database + Partition"`.

---

## Task 6: client.ts (CouchDB)

**Files:**
- Create: `couchdb-node/src/client.ts`
- Create: `couchdb-node/tests/client.integration.test.ts`

**Interfaces:**
- Consumes: `translate` (Task 3); `Database` (Task 5); `tests/helpers.ts` (Task 5); generated `Configuration`, `ServerApi`, `AuthenticationApi`, `DatabasesApi`, `ReplicationApi`.
- Produces: `class CouchDB` with `constructor(url="http://localhost:5984", username?, password?)` and async `info()`, `up()`, `uuids(count=1)`, `allDbs()`, `login(name,password)`, `logout()`, `session()`, `createDatabase(name, partitioned=false): Promise<Database>`, `deleteDatabase(name)`, `database(name): Database`, `replicate(source, target, options?={})`, and `close()`. Internally builds one shared `Configuration` with basic auth and a cookie-injecting `pre` middleware over a private mutable `{cookie?}`; `database()` passes that `Configuration` to `Database`.

- [ ] **Step 1: Write failing integration tests** `tests/client.integration.test.ts`, each `skip`-gated on `serverUp()`:
  - server: `info().couchdb === "Welcome"`, `up() === true`, `uuids(3)` has 3 unique.
  - db lifecycle: `createDatabase(n)`, `allDbs()` includes `n`, second create rejects with `PreconditionFailed`, `deleteDatabase(n)`.
  - sessions: **wrong password → `login` rejects with `Unauthorized`, cookie unchanged** (Review Focus); `session().userCtx.name` is `null` anonymous / `USER` after login; `logout()` returns to anonymous.

- [ ] **Step 2: Run to verify they fail** — `npx vitest run tests/client.integration.test.ts`. Expected: FAIL (or skip if no server — run against the Docker CouchDB from Task 9, or a local one).

- [ ] **Step 3: Implement `src/client.ts`.** Cookie capture: call the `authApi` raw variant for `_session`, read `Set-Cookie` (`res.raw.headers.getSetCookie?.()[0] ?? res.raw.headers.get("set-cookie")`), store the `name=value` pair; `logout` clears it. `replicate`: bare names → `{url: \`${host}/${name}\`, auth:{basic:{username,password}}}` when credentials set, else `{url}` for `://` inputs (mirror Python `_db_url`).

- [ ] **Step 4: Run to verify they pass** — `npx vitest run tests/client.integration.test.ts`. Expected: PASS against a live CouchDB.

- [ ] **Step 5: Commit** — `git add src/client.ts tests/client.integration.test.ts && git commit -m "feat: CouchDB server client + sessions + replicate"`.

---

## Task 7: src/index.ts barrel + full build

**Files:**
- Create: `couchdb-node/src/index.ts`

**Interfaces:**
- Produces: the package entry re-exporting `CouchDB`, `Database`, `Partition`, `ChangesFeed`, types `Doc`, `FindResult`, `ChangesResult`, `Change`, and all error classes + `CouchDBError`.

- [ ] **Step 1: Write `src/index.ts`** re-exporting the public surface.
- [ ] **Step 2: Build** — `npm run build`. Expected: `dist/src/index.{js,d.ts}` present, no type errors.
- [ ] **Step 3: Full unit run** — `npx vitest run tests/errors.test.ts tests/changes.unit.test.ts tests/database.unit.test.ts tests/sync-version.test.ts`. Expected: PASS.
- [ ] **Step 4: Commit** — `git add src/index.ts && git commit -m "feat: public API barrel"`.

---

## Task 8: Conformance step_impl (all 11 specs)

**Files:**
- Create: `couchdb-node/conformance/manifest.json` (`{ "Language": "js" }`)
- Create: `couchdb-node/conformance/env/default/{default.properties,js.properties}`
- Create: `couchdb-node/conformance/step_impl/steps.ts`
- Create: `couchdb-node/scripts/conformance.sh`

**Interfaces:**
- Consumes: the built wrapper (`CouchDB`, `CouchDBError`, `NotFound`).
- Produces: a Gauge `js` project binding every step text in `couchdb-sdk-generator/conformance/specs/*.spec` to the wrapper.

- [ ] **Step 1: Write `scripts/conformance.sh`** adapted from `couchdb-python/scripts/conformance.sh`: resolve `CONFORMANCE_SPECS` (default `../couchdb-sdk-generator/conformance/specs`), `rm -rf conformance/specs && cp -r`, `gauge()` = `npx -y @getgauge/cli@1.6.38`, `gauge install js`, `gauge run specs "$@"`.

- [ ] **Step 2: Write `manifest.json` + `env/default/js.properties`** (`STEP_IMPL_DIR = step_impl`; TypeScript steps compiled via the js runner / `ts-node` as the runner requires).

- [ ] **Step 3: Implement `step_impl/steps.ts`** — one binding per step text in the specs (the full list is in `couchdb-python/conformance/step_impl/steps.py`: connections, server, auth, databases, documents, Mango, design/views, attachments, changes, security, partitions, replication). Use gauge-js `Step("…", async (…) => {…})` with the **exact** step text, a scenario data-store for `couch`/`db`/remembered values, an `afterScenario` hook dropping created databases, and an `assertStatus(status, fn)` helper that asserts `CouchDBError.status`. Numbers arrive as strings — convert in-step (parity with Python).

- [ ] **Step 4: Run the suite** — from `couchdb-node/`, `bash scripts/conformance.sh` against a live CouchDB. (If no local CouchDB yet, defer the green run to Task 9's container.) Expected: 0 skipped, 0 failed.

- [ ] **Step 5: Commit** — `git add conformance scripts/conformance.sh && git commit -m "test: Gauge js conformance step_impl"`.

---

## Task 9: Dockerized conformance (one-command local green)

**Files:**
- Create: `couchdb-node/conformance/Dockerfile`
- Create: `couchdb-node/conformance/docker-compose.yml`
- Modify: `couchdb-node/README.md` (document `docker compose run --rm conformance`)

**Interfaces:**
- Consumes: Tasks 1–8 (built SDK + step_impl + `conformance.sh`).
- Produces: `docker compose run --rm conformance` → full suite green, no local toolchain needed.

- [ ] **Step 1: Write `conformance/Dockerfile`** — `node:20-bookworm`; `npm install -g @getgauge/cli@1.6.38 && gauge install js` (verified working on 2026-10-09); copy the repo, `npm ci`, `npm run build`; default `CMD` runs `scripts/conformance.sh`.

- [ ] **Step 2: Write `conformance/docker-compose.yml`** — service `couchdb` (`couchdb:3`, `COUCHDB_USER=admin`/`COUCHDB_PASSWORD=password`, healthcheck on `/_up`); service `conformance` (build the Dockerfile, `COUCHDB_URL=http://couchdb:5984`, `depends_on: couchdb: condition: service_healthy`), bind-mount shared specs from `../../couchdb-sdk-generator/conformance/specs`.

- [ ] **Step 3: Run it** — `docker compose -f conformance/docker-compose.yml run --rm conformance`. Expected: Gauge reports 0 failed, 0 skipped across all 11 specs. (Also create `_users`/`_global_changes` as CouchDB single-node setup requires, via the compose init or the script.)

- [ ] **Step 4: Commit** — `git add conformance/Dockerfile conformance/docker-compose.yml README.md && git commit -m "test: dockerized conformance runner"`.

---

## Task 10: CI workflow (mirror Python)

**Files:**
- Create: `couchdb-node/.github/workflows/ci.yml`
- Create: `couchdb-node/.github/workflows/release.yml`

**Interfaces:**
- Consumes: `npm test`, `scripts/conformance.sh`, `scripts/sync-version.mjs --check`.

- [ ] **Step 1: Write `ci.yml`** mirroring `couchdb-python/.github/workflows/ci.yml`: a `vitest` job (Node 18/20/22 matrix, `couchdb:3.4` service, wait-for-`_up` + create `_users`, `npm ci`, `npm run build`, `npm test`) and a `conformance` job (checkout this repo + sparse-checkout `couchdb-sdk-generator/conformance`, Node 20, `bash scripts/conformance.sh`, upload `conformance/reports/html-report`). Add `node scripts/sync-version.mjs --check` as a step in the vitest job.

- [ ] **Step 2: Write `release.yml`** — on `v*` tags, `npm ci && npm run build && npm publish` (npm provenance / `NODE_AUTH_TOKEN`), mirroring the Python release job's shape.

- [ ] **Step 3: Lint locally** — `npx -y @action-validator/cli@0.6.0 .github/workflows/ci.yml` (or `actionlint` if available). Expected: valid.

- [ ] **Step 4: Commit** — `git add .github && git commit -m "ci: test + conformance + release workflows"`.

---

## Notes for the executor

- Two repos: generator-config edits (Task 1) commit to `couchdb-sdk-generator`; all else to the new `couchdb-node` repo.
- The spec files and `generate.sh` are untouched; no copy-back to the generator repo is needed (no new scenarios).
- If Gauge/Docker cannot run in the execution environment, land Tasks 1–7 + 10 and leave Tasks 8–9's green run for CI, noting conformance as unverified locally (as the Python changes-feed session did). The Docker image install path is already verified.
