#!/usr/bin/env bash
#
# Regression test for src/scripts/git_fetch_parents.sh.
#
# Verifies that git_fetch_parents correctly fetches the parents of a
# commit that sits at the shallow-clone boundary.  Shallow-aware
# commands such as `git show --format=%P`, `git log --pretty=%P`,
# and `git rev-list --parents` all return an EMPTY parent list for
# commits listed in `.git/shallow` — exactly the subset for which
# this function is meant to do useful work.  The only reliable way
# to recover the true parent list of a shallow-boundary commit is to
# read the raw commit object via `git cat-file -p`.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../src/scripts/git_fetch_parents.sh
. "${REPO_ROOT}/src/scripts/git_fetch_parents.sh"

MOCK_REPO_URL="https://github.com/fulcrumgenomics/fetch-through-merge-base-mock.git"
TEST_REF="test-0001-head-ref"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

git clone --quiet --depth=1 "${MOCK_REPO_URL}" "${TMP}/repo" > /dev/null
cd "${TMP}/repo"

# Fetch the test ref at depth=1 so it sits at the shallow boundary.
git fetch --quiet --update-shallow --depth=1 origin "${TEST_REF}:__head__"
sha="$(git rev-parse __head__)"
echo "Test subject: commit ${sha} (shallow boundary)"

# Ground-truth: read the commit's real parent list directly from the
# raw object.  The test reuses the same `cat-file`+awk technique as
# the SUT on purpose — both must bypass shallow-aware porcelain to
# recover the true parent list of a shallow-boundary commit.  The
# expected value here is computed from the commit we hand to the
# SUT, so it remains shallow-boundary-aware independently of the
# SUT's internal discovery.
expected_parents=()
while IFS= read -r line; do
    expected_parents+=("${line}")
done < <(git cat-file -p "${sha}" \
    | awk '
        in_body { next }
        /^$/ { in_body = 1; next }
        $1 == "parent" { print $2 }
    ')

if [ "${#expected_parents[@]}" -eq 0 ]; then
    echo "ERROR: test fixture invariant broken — commit ${sha} has no parents"
    echo "       recorded in its raw object.  Pick a non-root commit for this test."
    exit 2
fi
echo "Expected parent(s):"
printf '  %s\n' "${expected_parents[@]}"

# Sanity: each expected parent should NOT already be present locally,
# otherwise the test would trivially pass regardless of SUT behavior.
for parent in "${expected_parents[@]}"; do
    if git cat-file -e "${parent}^{commit}" 2>/dev/null; then
        echo "ERROR: test fixture invariant broken — parent ${parent} is already local."
        echo "       Rework the test to exercise a commit whose parents are not yet fetched."
        exit 2
    fi
done

# --- SUT invocation ---
git_fetch_parents "${sha}"

# --- Assertions ---
missing=()
for parent in "${expected_parents[@]}"; do
    if ! git cat-file -e "${parent}^{commit}" 2>/dev/null; then
        missing+=("${parent}")
    fi
done

if [ "${#missing[@]}" -gt 0 ]; then
    echo "FAIL: git_fetch_parents did not fetch parent(s):"
    printf '  %s\n' "${missing[@]}"
    echo
    echo "This is the shallow-aware-parent bug: parent discovery must read"
    echo "the raw commit object (e.g. via 'git cat-file -p'), not a"
    echo "shallow-aware command like 'git show --format=%P'."
    exit 1
fi

echo "PASS: git_fetch_parents fetched all expected parents"
