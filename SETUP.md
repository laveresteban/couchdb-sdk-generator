# One-time setup

The automation needs credentials that only a person can create.

## 1. Cross-repo token: a GitHub App (recommended)

A GitHub App gives short-lived tokens scoped to just these repos, which is
better than a personal access token.

1. Create it at <https://github.com/settings/apps/new>:
   - Webhook: off
   - Repository permissions: **Contents: Read and write**, **Pull requests: Read and write**, **Metadata: Read**
2. Generate a private key, then install the app on `couchdb-openapi`,
   `couchdb-sdk-generator`, `couchdb-python` and `couchdb-node`
   (and `couchdb-android` if it should get automated PRs later).
3. In each of those repos, add the secrets `SDK_APP_ID` and `SDK_APP_PRIVATE_KEY`.
4. In the workflows, mint a token before the steps that use `SDK_BOT_TOKEN`:
   ```yaml
   - id: app-token
     uses: actions/create-github-app-token@v1
     with:
       app-id: ${{ secrets.SDK_APP_ID }}
       private-key: ${{ secrets.SDK_APP_PRIVATE_KEY }}
       owner: ${{ github.repository_owner }}
   # then use ${{ steps.app-token.outputs.token }}
   ```

**Quicker alternative:** a fine-grained personal access token.

1. Open <https://github.com/settings/personal-access-tokens/new>, with
   **Resource owner** set to `laveresteban`.
2. **Repository access → Only select repositories**: pick `couchdb-openapi`,
   `couchdb-sdk-generator`, `couchdb-python` and `couchdb-node`. With
   "Public repositories", GitHub only offers read-only permissions.
3. **Repository permissions**:
   - Contents: **Read and write** (send the dispatch, push the regen branch)
   - Pull requests: **Read and write** (open the regen PR)
   - Metadata: Read-only (added automatically); everything else: No access
4. Store it in the two repos whose workflows use it:

```sh
gh secret set SDK_BOT_TOKEN --repo laveresteban/couchdb-openapi
gh secret set SDK_BOT_TOKEN --repo laveresteban/couchdb-sdk-generator
```

Fine-grained tokens expire (at most a year). Set a reminder, or use the GitHub App above.

What uses it:
| Repo | Workflow | Why |
|------|----------|-----|
| couchdb-openapi | release.yml | sends `spec-released` to the generator |
| couchdb-sdk-generator | generate.yml | reads the spec, opens PRs in SDK repos (skipped while unset) |


## 2. PyPI trusted publishing (couchdb-python)

No API token needed:
1. On <https://pypi.org/manage/account/publishing/>, add a pending publisher:
   project `couchdb-sdk`, owner `laveresteban`, repo `couchdb-python`,
   workflow `release.yml`, environment `pypi`.
2. In GitHub, create the `pypi` environment in `couchdb-python`
   (Settings → Environments), ideally requiring your approval.
3. Release: `git tag v0.2.0 && git push --tags` in `couchdb-python`.

## 3. npm publishing (couchdb-node)

`release.yml` runs `npm publish --provenance` with `NPM_TOKEN`:
1. On npmjs.com, create a granular access token with publish rights for
   `couchdb-node` (or an automation token before the first publish).
2. In GitHub, create the `npm` environment in `couchdb-node` (Settings →
   Environments) and add `NPM_TOKEN` as an environment secret.
3. Release: `git tag v0.6.0 && git push --tags` in `couchdb-node`. The workflow
   checks that the tag matches `package.json` and the spec version.

