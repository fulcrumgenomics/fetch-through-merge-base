# Changelog

## [v1.0.0] (2024-01-22)

- first official release!

[v1.0.1]: https://github.com/fulcrumgenomics/setup-latch/releases/tag/v1.0.0

## 0.4.0

* [#1] Add `fallback_base_ref` and `fallback_hed_ref` inputs that can be used when this action is run on not a PR.
* [#1] Add `base_ref` and `head_ref` outputs that are computed during the action.
* [#1] Add `fail_after` input to avoid infinitely trying to find a common ancestor.

## 0.3.0

Allow `--deepen` length to be customized

## 0.2.0

Expose `base_ref` and `head_ref` action inputs to support use in workflows
triggered by events other than `pull_request`.

## 0.1.0

Initial version
