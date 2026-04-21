# Release

Releases are produced by pushing a `vX.Y.Z` tag to `main`. The
[`publish` workflow](./.github/workflows/release.yml) then runs the test suite,
generates a changelog with [git-cliff](https://git-cliff.org/), and creates a
GitHub Release, also moving the floating major-version tag (e.g. `v1`) to the
new commit.

All contributions land on `main` via pull request; there is no separate
`develop` branch.

## Cutting a release

1. Ensure the [CHANGELOG](./CHANGELOG.md) has an entry for `vX.Y.Z`.

2. Bump `package.json` and `package-lock.json` to the new version:

   ```bash
   npm version --no-git-tag-version X.Y.Z
   ```

   The `check-version` job in the `publish` workflow compares `package.json`
   to the tag and fails the release if they don't match.

3. If this is a major version bump, update all example YAML in the
   [README](./README.md) (e.g. `@v1` → `@v2`).

4. Open a pull request with the above changes and merge it to `main`.

5. Tag the merge commit on `main` and push the tag:

   ```bash
   git checkout main
   git pull origin main
   git tag -a -m 'Release version vX.Y.Z' vX.Y.Z
   git push origin vX.Y.Z
   ```

   Replace `X.Y.Z` with the appropriate version number. Pushing the tag
   triggers the `publish` workflow.
