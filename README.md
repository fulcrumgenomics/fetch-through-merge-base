# fetch-through-merge-base

A GitHub Action for fetching PR commits through the merge-base

* [Usage](#usage)
  * [Inputs](#inputs)
  * [Outputs](#outputs)
* [Examples](#examples)
* [Motivation](#motivation)

<p>
<a href float="left"="https://fulcrumgenomics.com"><img src=".github/logos/fulcrumgenomics.svg" alt="Fulcrum Genomics" height="100"/></a>
</p>

[Visit us at Fulcrum Genomics](www.fulcrumgenomics.com) to learn more about how we can power your Bioinformatics with fetch-through-merge-base and beyond.

<a href="mailto:contact@fulcrumgenomics.com?subject=[GitHub inquiry]"><img src="https://img.shields.io/badge/Email_us-brightgreen.svg?&style=for-the-badge&logo=gmail&logoColor=white"/></a>
<a href="https://www.fulcrumgenomics.com"><img src="https://img.shields.io/badge/Visit_Us-blue.svg?&style=for-the-badge&logo=wordpress&logoColor=white"/></a>

## Usage

<!-- start usage -->

### Inputs

```yaml
- uses: fulcrumgenomics/fetch-through-merge-base@v1
  with:
    # The base ref or target branch in the workflow run. If empty or not defined, the
    # `fallback-base-ref` input ref will be used.
    # Default: ${{ github.base_ref }}
    base-ref: ''

    # The head ref or source branch in the workflow run. If empty or not defined, the
    # `fallback-head-ref` input ref will be used.
    # Default: ${{ github.head_ref }}
    head-ref: ''

    # The base ref to use when `base-ref` is empty or not defined. For example, when
    # using `github.base_ref` for `base-ref`, and the workflow is not a `pull_request`
    # or `pull_request_target`, then the `base-ref` is not defined, so this ref will
    # be used.
    # Default: main
    fallback-base-ref: ''

    # The head ref to use when `head-ref` is empty or not defined. For example, when
    # using `github.head_ref` for `head-ref`, and the workflow is not a `pull_request`
    # or `pull_request_target`, then the `head-ref` is not defined, so this ref will
    # be used.
    # Default: ${{ github.sha }}
    fallback-head-ref: ''

    # The number of commits to increase from the tip of each base and ref history when
    # `git merge-base` fails to find the common ancestor of the two commits.
    # Default: 10
    deepen-length: ''

    # The number of attempts to deepen before the action fails.
    # Default: 100
    fail-after: ''

    # The working directory to switch to when runnign this action.
    # Default: ./
    working-directory: ''

    # True to fetch all commits if number of attempts to deepen reaches its limit,
    # false to fail the action.
    # Default: false
    fallback-fetch-all: ''
```

### Outputs

| Output | Description |
| --- | --- |
| `base-ref` | The base ref computed by the workflow run. This differs from the input base ref when the latter is empty and the fallback base ref is used. |
| `head-ref` | The head ref computed by the workflow run. This differs from the input head ref when the latter is empty and the fallback head ref is used. |
| `ancestor-ref` | The best common ancestor between the base and head references, or empty if none was found. |

Additionally, the `GITHUB_BASE_REF` and `GITHUB_HEAD_REF` environment variables will be
set to the base and head ref, after applying any fallback (i.e. when `base-ref`
or `head-ref` properties are not defined).

<!-- end usage -->


## Examples

By default, the action will pull the "base ref" and "head ref" from the
[`github` context], i.e. `${{ github.base_ref }}` and `${{ github.head_ref }}`.

This means usage can be as simple adding
`- uses: fulcrumgenomics/fetch-through-merge-base@v1` to any `pull_request` workflow:

```yml
name: Example Workflow
on: pull_request

jobs:
  example_job:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          ref: ${{ github.head_ref }}
      - uses: fulcrumgenomics/fetch-through-merge-base@v1
      # now we've fetched commits through the merge-base of the source branch
      # and target branch of the pull request, so we can do things like:
      - run: git merge-base ${{ github.base_ref }} ${{ github.head_ref }}
      - run: git log --oneline ${{ github.base_ref }}..
      - run: git diff --name-only ${{ github.base_ref }}...
```

[`github` context]: https://docs.github.com/en/actions/reference/context-and-expression-syntax-for-github-actions#github-context

Note that the `${{ github.base_ref }}` and `${{ github.head_ref }}` properties
are only available when the event that triggers the workflow is `pull_request`.
So, in order to use this action in a workflow that is triggered by a different
event, like `push`, the refs must be passed as inputs to the action. The
following example fetches commits through the merge-base of the `main` branch
and the commit that triggered the workflow run:

```yml
name: Example Workflow
on: push

jobs:
  example_job:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: fulcrumgenomics/fetch-through-merge-base@v1
        with:
          base-ref: main
          head-ref: ${{ github.sha }}
```

Alternatively, fallback refs may be provided for the base and head refs with
`fallback-base-ref` and `fallback-head-ref` respectively.

## Motivation

The default behavior of [`actions/checkout`] v4 is to only fetch a single commit
because 1) often that commit is all that's needed and 2) fetching only one
commit is much faster than fetching everything, especially in large
repositories. If more history is needed, the `fetch-depth` input can be passed
to `actions/checkout` to fetch a number of commits up to the current commit (or
all history for all branches and tags via `fetch-depth: 0`). However, there's no
"fetch all commits within the current pull request" option (the depth of which
can vary greatly from one pull request to another). That's what this action
aims to provide!

The way this action works is by iteratively [deepening] the history of the
shallow clone until the common ancestor of the pull request source branch and
target branch (i.e. the [`merge-base`]) has been found. By default, the action
uses `--deepen=10`, but this can be tuned through the `deepen-length` action
input to optimize the `git fetch` calls for a given repository. The trade-off of
setting a large `deepen-length` is that the action may fetch more unnecessary
commits when running on a pull request that only has a few commits. On the other
hand, setting a small `deepen-length` may lead to many `git fetch` calls in a
row in order to fetch all the commits of a large PR, with each call incurring
additional overhead.

Note: For small repositories, `actions/checkout` with `fetch-depth: 0` may
finish quickly, so feel free to just use that initially. This action can be
swapped in later when the repository has grown to the point where fetching the
full history is slow.

The `fail-after` input may be used to limit the maximum number of times additional
commits are fetched when "deepening".

[`actions/checkout`]: https://github.com/actions/checkout
[deepening]: https://git-scm.com/docs/git-fetch#Documentation/git-fetch.txt---deepenltdepthgt
[`merge-base`]: https://git-scm.com/docs/git-merge-base
