# CLAUDE.md — couchdb-sdk-generator

Hub repo for the CouchDB SDK family. Turns `couchdb-openapi` into SDKs with
OpenAPI Generator and owns the shared Gauge conformance specs.

Sibling repos (clone side by side):

| Repo | Role | Spec version it's on |
|------|------|----------------------|
| couchdb-openapi | source of truth (`openapi.yaml`) | 0.5.0 |
| couchdb-sdk-generator | this repo: configs, templates, conformance specs | — |
| couchdb-python | generated `couchdb_client` + hand-written `couchdb_sdk` | 0.4.0 |
| couchdb-node | generated `couchdb_client/` + hand-written `src/` | 0.3.0 |
| couchdb-android | hand-written offline sync (no generated code yet) | n/a |

Each repo has its own CLAUDE.md with repo-specific fixes and features.

## Commands

```sh
npm ci
npm run generate:python          # -> ../couchdb-python
npm run generate:node            # -> ../couchdb-node/couchdb_client + sync-version
docker compose up -d couchdb     # CouchDB 3.4 on :5984 (admin/password)
docker compose run --rm gauge --tags changes   # python conformance only
```

## Rules

- Spec change → add a scenario in `conformance/specs` in the same change.
  Step text describes behavior, never a language API. All params are quoted strings.
- Don't edit generated code in SDK repos. Fix the spec, config or a template.
- Avoid the spec patterns listed in README ("Spec patterns to avoid").

## Cross-repo state (Oct 2026 review)

The spec is at 0.5.0, but neither generated SDK has caught up, and the
conformance specs on `main` already require features the SDKs don't have:

- `sync.spec` (revs diff, bulk get, `_local`, `new_edits:false`, conflicts,
  selector filter) has no step implementations in couchdb-python or couchdb-node.
- The continuous-feed scenarios in `changes.spec` have no steps in couchdb-node.
- Both SDKs' conformance jobs check out this repo's `main`, so their next CI run
  should fail on those scenarios. The last green runs predate the spec push.
  Fix order: regenerate both SDKs to 0.5.0, then implement the steps.

## Fixes (this repo)

1. **`generate.yml` only regenerates Python.** Matrix is `[python]`. Adding
   `typescript` won't work as-is: the job checks out `couchdb-${{ matrix.lang }}`
   (there is no `couchdb-typescript`) and calls `generate.sh` with default paths,
   but Node needs `-o ../couchdb-node/couchdb_client` plus `sync-version.mjs`.
   Drive the matrix from `sdk-matrix.yaml` (repo, output dir, post-step) instead
   of hard-coding it.
2. **`sdk-matrix.yaml` is not read by anything.** README says it maps spec ref
   and languages to repos, but no script or workflow loads it. Either wire it
   in (see 1) or delete it so it can't drift.
3. **`gauge-python.Dockerfile` builds `FROM couchdb-gauge-probe:latest`**, a
   local image that isn't defined in any repo. `docker compose run gauge`
   fails on a clean machine. Base it on a public image (couchdb-node's
   `conformance/Dockerfile` does node:20 + gauge CLI) and add `gauge install python`.
4. **docker-compose only runs Python conformance.** Add `gauge-node` and
   `gauge-java` services (or one service with an `SDK` arg) so all three SDKs
   can be checked against the same CouchDB.
5. **SETUP.md lists only couchdb-python.** The token/App must also be installed
   on couchdb-node and couchdb-android, and npm publishing (`NPM_TOKEN` or
   trusted publishing, `npm` environment) isn't documented.
6. **Regen branch name collides.** `branch: regen/spec-${SPEC_REF}` means every
   push to `main` here reuses `regen/spec-main`. Fine for one open PR, but
   a spec tag and a template change can't be reviewed separately. Add the
   generator SHA or run id.
7. **No CI for this repo.** Nothing validates the specs or configs on PR. Add a
   job that runs `generate.sh` for each language into a temp dir and fails on
   errors, plus `gauge validate` on `conformance/specs`.
8. `conformance/README.md` "Areas covered" table doesn't mention the
   checkpoint/continuous reader scenarios in `changes.spec`.
9. `templates/python` and `templates/typescript` only hold a README. Fine, but
   the Python "untyped `{}` sent as null" bug could be fixed in a model
   template instead of in every wrapper call.

## Features to add

- **Conformance scenarios** for gaps that bit us before or that SDKs handle
  differently today:
  - view query with `start_key`/`end_key` (catches the untyped-`{}` null bug)
  - attachment content type round trip (spec only allows octet-stream, see openapi CLAUDE.md)
  - cookie session expiry/refresh
  - `_bulk_docs` partial failure (one doc conflicts, others succeed)
  - database names that need encoding (`a/b`, `a+b`)
  - `_changes` longpoll timeout returning empty, `seq_interval` null seqs
  - push/pull round trip with conflicts (for couchdb-android `sync` tag)
- **Kotlin target** (`config/kotlin.yaml`) from `docs/android-offline-sync.md`.
  Blocked on the open-`Document` problem. Options: a template that maps
  `Document` to `JsonObject`, or generate only non-document APIs (server,
  auth, security, `_index`) for couchdb-android to use.
- **Release automation**: when a regen PR merges in an SDK repo, tag that repo
  with the spec version so PyPI/npm publish without a manual tag.
- **Pin the spec ref** in `sdk-matrix.yaml` to tags for releases (it's `main` now).
- **Design doc status**: `docs/android-offline-sync.md` still says continuous
  `_changes` is open; it's in spec 0.4.0. Update the table.
