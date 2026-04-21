#!/usr/bin/env bash
#
# Unit test for src/scripts/git_ungraft.sh.
#
# Builds a self-contained shallow clone from a local bare repo (no
# network) and exercises three behaviors:
#   1. Before parents are fetched: no candidates, shallow file unchanged
#      (mtime preserved).
#   2. --dry-run: prints "Would ungraft <sha>" lines without modifying
#      .git/shallow.
#   3. Default (non-dry) run: rewrites .git/shallow, removing the
#      entries whose parents are now locally present.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNGRAFT="${REPO_ROOT}/src/scripts/git_ungraft.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

REMOTE="${TMP}/remote.git"
SRC="${TMP}/src"
CLIENT="${TMP}/client"

# --- build a deterministic 20-commit linear history in a local bare repo ---
# Enough commits that a small `--deepen` leaves the file non-empty so
# cases 2 and 3 have something to assert against.
git init --quiet --bare -b main "${REMOTE}"
git init --quiet -b main "${SRC}"
(
    cd "${SRC}"
    for i in $(seq 1 20); do
        git -c user.email=t@t -c user.name=t commit --quiet --allow-empty -m "c${i}"
    done
    git push --quiet "${REMOTE}" main
)

# --- shallow clone at depth=1 ---
git clone --quiet --depth=1 "file://${REMOTE}" "${CLIENT}"
cd "${CLIENT}"

shallow_file="${CLIENT}/.git/shallow"
if [ ! -f "${shallow_file}" ]; then
    echo "FAIL: expected .git/shallow to exist after --depth=1 clone"
    exit 1
fi
shallow_before="$(cat "${shallow_file}")"

# --- case 1: no candidates, no rewrite, mtime preserved ---
# Parents of the shallow-boundary commit are NOT present locally, so
# no entry is ungraftable.  The script must not rewrite the file.
mtime_before="$(stat -f %m "${shallow_file}" 2>/dev/null || stat -c %Y "${shallow_file}")"
output="$(bash "${UNGRAFT}")"
mtime_after="$(stat -f %m "${shallow_file}" 2>/dev/null || stat -c %Y "${shallow_file}")"
if [ "${output}" != "No candidate commits to ungraft" ]; then
    echo "FAIL (case 1): expected 'No candidate commits to ungraft'"
    echo "  got: ${output}"
    exit 1
fi
if [ "${mtime_before}" != "${mtime_after}" ]; then
    echo "FAIL (case 1): .git/shallow mtime changed on no-op run"
    exit 1
fi
if [ "$(cat "${shallow_file}")" != "${shallow_before}" ]; then
    echo "FAIL (case 1): .git/shallow contents changed on no-op run"
    exit 1
fi
echo "PASS (case 1): no candidates, shallow file untouched"

# --- fetch HEAD's parent at depth=1 so HEAD's parents are locally present ---
# This mirrors what src/scripts/git_fetch_parents.sh does in production:
# the parent SHA is both present locally AND added to .git/shallow,
# which makes HEAD (still in .git/shallow) ungraftable.
head_sha="$(git rev-parse HEAD)"
head_parent="$(git cat-file -p "${head_sha}" \
    | awk '/^$/ { exit } $1 == "parent" { print $2 }' | head -n1)"
if [ -z "${head_parent}" ]; then
    echo "FAIL: could not determine HEAD's parent SHA"
    exit 1
fi
git fetch --quiet --update-shallow --depth=1 origin "${head_parent}:__parent__"
if [ ! -f "${shallow_file}" ]; then
    echo "FAIL: expected .git/shallow to remain after parent fetch"
    exit 1
fi

# Pick a shallow entry whose parents are now all locally present.
ungraftable=""
while IFS= read -r sha || [ -n "${sha}" ]; do
    [ -z "${sha}" ] && continue
    all_present=1
    parents="$(git cat-file -p "${sha}" | awk '/^$/ { exit } $1 == "parent" { print $2 }')"
    [ -z "${parents}" ] && continue  # root commit — skip
    for p in ${parents}; do
        git cat-file -e "${p}^{commit}" 2>/dev/null || { all_present=0; break; }
    done
    if [ "${all_present}" -eq 1 ]; then
        ungraftable="${sha}"
        break
    fi
done < "${shallow_file}"
if [ -z "${ungraftable}" ]; then
    echo "FAIL: no shallow entry with locally-present parents after parent fetch"
    echo "--- .git/shallow ---"
    cat "${shallow_file}"
    echo "--------------------"
    exit 1
fi
echo "Ungraftable candidate: ${ungraftable}"

# --- case 2: --dry-run prints candidates without rewriting ---
mtime_before="$(stat -f %m "${shallow_file}" 2>/dev/null || stat -c %Y "${shallow_file}")"
contents_before="$(cat "${shallow_file}")"
dry_output="$(bash "${UNGRAFT}" --dry-run)"
mtime_after="$(stat -f %m "${shallow_file}" 2>/dev/null || stat -c %Y "${shallow_file}")"
if ! grep -qxF "Would ungraft ${ungraftable}" <<< "${dry_output}"; then
    echo "FAIL (case 2): expected 'Would ungraft ${ungraftable}' in dry-run output"
    echo "--- dry-run output ---"
    echo "${dry_output}"
    echo "----------------------"
    exit 1
fi
if [ "${mtime_before}" != "${mtime_after}" ]; then
    echo "FAIL (case 2): --dry-run changed .git/shallow mtime"
    exit 1
fi
if [ "$(cat "${shallow_file}")" != "${contents_before}" ]; then
    echo "FAIL (case 2): --dry-run changed .git/shallow contents"
    exit 1
fi
echo "PASS (case 2): --dry-run printed candidate and left shallow file untouched"

# --- case 3: real run removes the ungraftable entry ---
real_output="$(bash "${UNGRAFT}")"
if ! grep -qxF "Ungrafted ${ungraftable}" <<< "${real_output}"; then
    echo "FAIL (case 3): expected 'Ungrafted ${ungraftable}' in output"
    echo "--- output ---"
    echo "${real_output}"
    echo "--------------"
    exit 1
fi
if grep -qxF "${ungraftable}" "${shallow_file}"; then
    echo "FAIL (case 3): ${ungraftable} still present in .git/shallow after ungraft"
    exit 1
fi
echo "PASS (case 3): ungraftable entry removed from .git/shallow"

echo "PASS: test_git_ungraft.sh"
