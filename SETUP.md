# One-time setup

The automation needs credentials that only a person can create.

## 1. Cross-repo token: a GitHub App (recommended)

A GitHub App gives short-lived tokens scoped to just these repos, which is
better than a personal access token.

1. Create it at <https://github.com/settings/apps/new>:
   - Webhook: off
   - Repository permissions: **Contents: Read and write**, **Pull requests: Read and write**, **Metadata: Read**
2. Generate a private key, then install the app on `couchdb-openapi`,
   `couchdb-sdk-generator` and `couchdb-python`.
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

**Quicker alternative:** create a fine-grained PAT at
<https://github.com/settings/personal-access-tokens/new> with the same
permissions on the three repos, and store it as `SDK_BOT_TOKEN`:

```sh
for r in couchdb-openapi couchdb-sdk-generator couchdb-python; do
  gh secret set SDK_BOT_TOKEN --repo laveresteban/$r
done
```

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

