# Changelog

## [v1.5.0] (2026-04-21)

- Feature: drop the Python dependency — `git_ungraft` is now a pure-bash helper, and `actions/setup-python` is no longer installed (#62)
- Feature: `gha-timer` is now opt-out via a new `enable-timing` input (default `'true'`); set `enable-timing: 'false'` to skip installing it. When `gha-timer` is absent, the wrapper falls back to `::group::`/`::endgroup::` workflow commands so logs stay collapsible (#62)
- Fix: `git_fetch_parents` was a silent no-op on shallow-boundary commits — the exact case it exists to handle. Rewritten to read parents via `git cat-file -p` + awk header parser; regression test added (#62)
- CI: add a `shellcheck` job (strictest severity) and a `shell-tests` matrix (ubuntu/macos) running new unit tests for `git_ungraft.sh`, `git_fetch_parents.sh`, and `gha_timer_wrapper.sh` (#62)
- CI: set git identity before creating the annotated major-version tag in the release workflow (#61)

[v1.5.0]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.5.0

## [v1.4.3] (2026-04-20)

- Fix: parent extraction no longer matches commit message body lines that start with `parent ` (#58)
- Feature: use `gha-timer` for step timing and log grouping, and skip its banner (#35, #36)
- Feature: add a release workflow that publishes a GitHub Release and updates the floating major-version tag on tag push (#35)
- CI: pin GitHub Actions by commit SHA with trailing version comments; drop deprecated runners (#56)
- CI: bump `gha-timer` to v1.1.1 (#59)
- Fix: explicitly install Python 3.12 via `actions/setup-python` instead of relying on the runner's default (#57)
- Documentation: update Fulcrum Genomics logo to support light/dark themes; fix logo links (#39, #55)
- Chore: remove unused dependabot config; bump dev dependencies (#38)

[v1.4.3]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.4.3

## [v1.4.2] (2025-03-19)

- [#31] Fix `fail-after` number of iterations and related tests
- [#31] Fix `fallback-fetch-all` could never be reached
- [#30] Add badges to the README, and add a banner and beautify the logs 
- [#30] Add badges to the README, and add a banner and beautify the logs 
- Fix website link in README
- [#23] Bump the minor-npm-dependencies group across 1 directory with 3 updates

[v1.4.2]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.4.2

## [v1.4.1] (2025-03-03)

- Fix: ungraft did not add newlines to .git/shallow
- Fix: try fetching the parent commits in case of a merge commit

[v1.4.1]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.4.1

## [v1.4.0] (2025-03-03)

- Feature: improve fallback when the fetch script fails (#26)

[v1.4.0]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.4.0

## [v1.3.0] (2025-02-26)

- Feature: update and unshallow when fetching (#21)
- CI: improve testing (#22)

[v1.3.0]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.3.0

## [v1.2.1] (2025-02-26)

- Feature: ungraft any commits (#20). This is important when using with GitHub pull request commits which can be grafted.

[v1.2.1]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.2.1

## [v1.1.1] (2025-02-25)

- Fix: infinite loop after fetching all (#19)

[v1.1.1]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.1.1

## [v1.1.0] (2025-02-24)

- Feature: add the fallback-fetch-all parameter (#18)
- Feature: add the working-directory parameter (#17)
- Feature: re-add --quiet (#18)
- Fix: set -e should not exit when setting var to zero (#18)
- CI: use a mock repo for tests (#17)
- CI: test on more operating systems (#16)
- Documentation: add fulcrum genomics more prominently (#6)
- Documentation: fix versions in the examples (#5)
- Bump the minor-npm-dependencies group across 1 directory with 3 updates (#11)
- Bump eslint-plugin-github from 4.10.2 to 5.1.5 (#4)
- Bump @types/node from 20.17.15 to 22.10.8 (#2)

[v1.1.0]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.1.0

## [v1.0.1] (2025-01-22)

- Add script to update the README docs; updated the README docs (#1)

[v1.0.1]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.0.1

## [v1.0.0] (2025-01-22)

- first official release!

[v1.0.0]: https://github.com/fulcrumgenomics/fetch-through-merge-base/releases/tag/v1.0.0

## 0.4.0

* Add `fallback_base_ref` and `fallback_hed_ref` inputs that can be used when this action is run on not a PR.
* Add `base_ref` and `head_ref` outputs that are computed during the action.
* Add `fail_after` input to avoid infinitely trying to find a common ancestor.

## 0.3.0

Allow `--deepen` length to be customized

## 0.2.0

Expose `base_ref` and `head_ref` action inputs to support use in workflows
triggered by events other than `pull_request`.

## 0.1.0

Initial version
