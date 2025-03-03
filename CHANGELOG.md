# Changelog

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
