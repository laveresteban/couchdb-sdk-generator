# CLAUDE.md — couchdb-sdk-generator

Hub repo for the CouchDB SDK family. Turns `couchdb-openapi` into SDKs with
OpenAPI Generator and owns the shared Gauge conformance specs.

Sibling repos (clone side by side):

| Repo | Role | Spec version |
|------|------|--------------|
| couchdb-openapi | source of truth (`openapi.yaml`) | 0.7.0 |
| couchdb-sdk-generator | this repo: configs, templates, conformance specs | — |
| couchdb-python | generated `couchdb_client` + hand-written `couchdb_sdk` | 0.7.0 |
| couchdb-node | generated `couchdb_client/` + hand-written `src/` | 0.7.0 |
| couchdb-android | hand-written offline sync (no generated code yet) | n/a |

Each repo has its own CLAUDE.md with repo-specific fixes and features.
The suite has 46 scenarios; Python and Node pass all of them and get their
CI from `sdk-ci.yml` here. couchdb-android runs the
`documents | changes | sync | databases` tags with its own Gradle CI.
New scenarios need steps in each SDK before they land on this repo's `main`,
or the SDKs' conformance jobs fail on skips.

## Commands

```sh
npm ci
npm run generate:python          # bash scripts/generate.sh python
npm run generate:node            # bash scripts/generate.sh typescript (runs sync-version)
docker compose up -d couchdb     # CouchDB 3.4 on :5984 (admin/password)
docker compose run --rm gauge-python [--tags changes]
docker compose run --rm gauge-node
docker compose run --rm -e GAUGE_TAGS=sync gauge-android
```

`sdk-matrix.json` drives `generate.sh` and both workflows: per language the
config, SDK repo, output dir inside it, and a post step run in the SDK repo.

## Rules

- SDK CI lives here (`.github/workflows/sdk-ci.yml`) and the SDKs call it;
  change shared CI here, not in each SDK. Changes reach the SDKs on their
  next run (they track `@main`), so keep the inputs backward compatible.
- Hand-written SDK behavior is specified in `docs/sdk-design.md`; update it
  with any behavior change and mirror the change in the other SDKs.

- Spec change → add a scenario in `conformance/specs` in the same change.
  Step text describes behavior, never a language API. All params are quoted strings.
- Gauge reports scenarios with missing steps as *skipped* and still exits 0.
  Every SDK's `scripts/conformance.sh` fails on skips; keep it that way.
- Don't edit generated code in SDK repos. Fix the spec, config or a template.
- Avoid the spec patterns listed in README ("Spec patterns to avoid").
- CouchDB's `_changes` order isn't global across shards; don't write tests
  that assume doc A's change comes before doc B's.

## Fixes still open

Done: Python untyped-`{}` null bug fixed in `templates/python`; stale
generated files pruned by `generate.sh`; `scripts/check-specs.sh` (parse +
conventions) and a Docker job in CI that builds every runner image and runs
a smoke tag through each.

- None known.

## Features to add

- **Conformance scenarios** for gaps that bit us before or that SDKs handle
  differently today:
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
- **Pin the spec ref** in `sdk-matrix.json` to tags for releases (it's `main` now).
