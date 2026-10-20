# Releasing pub_health

Publishing uses **Trusted Publishing** (OIDC) with GitHub Actions.
No long-lived `PUB_TOKEN` is stored in the repository.

Official docs: https://dart.dev/tools/pub/automated-publishing

## One-time setup on pub.dev

1. Open https://pub.dev/packages/pub_health/admin
2. Under **Automated publishing**, enable **publishing from GitHub Actions**
3. Set:
   - **Repository:** `Ag1rin/pub_health`
   - **Tag pattern:** `v{{version}}`
4. Save

Optional: require a GitHub Actions environment named `pub.dev` and add
required reviewers in the GitHub repo settings.

## Workflow layout

| Workflow | Triggers | Purpose |
|---|---|---|
| `ci.yml` | pushes to `main`, pull requests | format / analyze / test |
| `publish.yml` | tags matching `v[0-9]+.[0-9]+.[0-9]+` | publish to pub.dev |

## Release steps

1. Update `version` in `pubspec.yaml` (e.g. `0.2.0`)
2. Update `CHANGELOG.md` under that version
3. Commit and merge to `main`
4. Create and push a matching tag:

```bash
git tag v0.2.0
git push origin v0.2.0
```

5. Confirm the **Publish to pub.dev** workflow succeeds:
   https://github.com/Ag1rin/pub_health/actions

The Git tag version (`v0.2.0`) **must** match `version:` in `pubspec.yaml`
(`0.2.0`). pub.dev rejects mismatches.

## Do not

- Store a pub.dev publishing token in GitHub Secrets
- Trigger publishing from ordinary pushes or pull requests
- Reuse an old tag for a different version
