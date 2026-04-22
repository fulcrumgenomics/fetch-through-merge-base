#!/usr/bin/env bash
#
# Unit test for src/scripts/git_ungraft.sh.
#
# Builds a self-contained shallow clone from a local bare repo (no
# network) and exercises four behaviors:
#   1. Before parents are fetched: no candidates, shallow file unchanged
#      (inode identity preserved — see case 1 rationale below).
#   2. --dry-run: prints "Would ungraft <sha>" lines without modifying
#      .git/shallow.
#   3. Default (non-dry) run: rewrites .git/shallow, removing the
#      entries whose parents are now locally present.
#   4. Run from a linked worktree: the script reads .git/shallow from
#      the common git dir, not the per-worktree gitdir.

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
#
# The last (tip) commit carries a message body larger than the pipe
# buffer (~64 KB on Linux, ~16 KB on macOS).  Because HEAD is the
# shallow-boundary commit after `clone --depth=1`, it is the first
# shallow entry the ungraft script walks, so it exercises the
# `git cat-file | awk` pipeline every case.  This is a regression
# guard for the SIGPIPE hazard in the awk parent parser: an
# early-exit awk closes the read end of the pipe, which kills
# `git cat-file` with SIGPIPE under `set -o pipefail` when the commit
# body exceeds the buffer.  With a buggy awk, the command
# substitution fails and `set -e` aborts the script.
#
# The body is fed via stdin (`git commit -F -`), not `-m`: Linux caps a
# single argv entry at `MAX_ARG_STRLEN` (131072 bytes) regardless of
# the total `ARG_MAX`, so a 200-KB `-m` value would hit "Argument list
# too long" on a Linux runner.  `printf` is a shell builtin, so no
# `exec()` is involved and the length limit does not apply.
big_body="$(head -c 200000 /dev/urandom | base64)"
git init --quiet --bare -b main "${REMOTE}"
git init --quiet -b main "${SRC}"
(
    cd "${SRC}"
    for i in $(seq 1 20); do
        if [ "${i}" -eq 20 ]; then
            printf 'c%s\n\n%s\n' "${i}" "${big_body}" \
                | git -c user.email=t@t -c user.name=t commit --quiet \
                    --allow-empty -F -
        else
            git -c user.email=t@t -c user.name=t commit --quiet \
                --allow-empty -m "c${i}"
        fi
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

# --- case 1: no candidates, no rewrite, file not replaced ---
# Parents of the shallow-boundary commit are NOT present locally, so
# no entry is ungraftable.  The script must not rewrite the file.
# We check inode identity (not mtime): the script rewrites via
# `mv "$tmp" "$shallow_file"`, which atomically replaces the file and
# therefore changes its inode.  An mtime check is unreliable because
# git's shallow-handling code may touch `.git/shallow` in place during
# read-only sub-commands run by the script, producing flaky failures.
#
# stat invocation is portable: try GNU (`-c %i`) first and fall back
# to BSD (`-f %i`).  The reverse order is a cross-platform trap — on
# GNU stat, `-f` is filesystem-info mode, which ignores `%i` and
# dumps a multi-line blob of free-block / free-inode counts.  Those
# counts tick between back-to-back calls on a busy CI runner, so
# two "before"/"after" captures would differ even when the file's
# real inode is unchanged, producing a cross-platform flake.
inode_before="$(stat -c %i "${shallow_file}" 2>/dev/null || stat -f %i "${shallow_file}")"
output="$(bash "${UNGRAFT}")"
inode_after="$(stat -c %i "${shallow_file}" 2>/dev/null || stat -f %i "${shallow_file}")"
if [ "${output}" != "No candidate commits to ungraft" ]; then
    echo "FAIL (case 1): expected 'No candidate commits to ungraft'"
    echo "  got: ${output}"
    exit 1
fi
if [ "${inode_before}" != "${inode_after}" ]; then
    echo "FAIL (case 1): .git/shallow inode changed on no-op run"
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
# awk consumes the full stream (no early `exit`) and emits only the
# first parent, so neither awk nor a downstream `head` can close the
# pipe early and SIGPIPE-kill `git cat-file` under `set -o pipefail`.
head_parent="$(git cat-file -p "${head_sha}" \
    | awk '
        in_body { next }
        /^$/ { in_body = 1; next }
        !printed && $1 == "parent" { print $2; printed = 1 }
    ')"
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
    parents="$(git cat-file -p "${sha}" \
        | awk '
            in_body { next }
            /^$/ { in_body = 1; next }
            $1 == "parent" { print $2 }
        ')"
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
# As in case 1, use inode identity to detect the script's `mv`-based
# rewrite; mtime is unreliable here (see case 1 comment).
inode_before="$(stat -c %i "${shallow_file}" 2>/dev/null || stat -f %i "${shallow_file}")"
contents_before="$(cat "${shallow_file}")"
dry_output="$(bash "${UNGRAFT}" --dry-run)"
inode_after="$(stat -c %i "${shallow_file}" 2>/dev/null || stat -f %i "${shallow_file}")"
if ! grep -qxF "Would ungraft ${ungraftable}" <<< "${dry_output}"; then
    echo "FAIL (case 2): expected 'Would ungraft ${ungraftable}' in dry-run output"
    echo "--- dry-run output ---"
    echo "${dry_output}"
    echo "----------------------"
    exit 1
fi
if [ "${inode_before}" != "${inode_after}" ]; then
    echo "FAIL (case 2): --dry-run replaced .git/shallow (inode changed)"
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

# --- case 4: works from a linked worktree ---
# Regression guard: `.git/shallow` lives in the common git dir, not
# the per-worktree gitdir.  The script must use `git rev-parse
# --git-common-dir` so that running it from a linked worktree still
# finds (and rewrites) the shallow file in the primary `.git`.  Using
# `--absolute-git-dir` would silently no-op ("No candidate commits to
# ungraft") in a linked worktree because `.git/worktrees/<name>/shallow`
# does not exist.
#
# Build a fresh ungraftable state: case 3 cleared the previous
# candidate, so fetch the head-parent's parent at --depth=1 so it
# joins the shallow boundary and the head-parent becomes ungraftable
# again.
grandparent="$(git cat-file -p "${head_parent}" \
    | awk '
        in_body { next }
        /^$/ { in_body = 1; next }
        !printed && $1 == "parent" { print $2; printed = 1 }
    ')"
if [ -z "${grandparent}" ]; then
    echo "FAIL (case 4): could not determine grandparent SHA for worktree test"
    exit 1
fi
git fetch --quiet --update-shallow --depth=1 origin \
    "${grandparent}:__grandparent__"
wt_candidate="${head_parent}"
if ! git cat-file -e "${grandparent}^{commit}" 2>/dev/null; then
    echo "FAIL (case 4): grandparent not local after fetch — test setup broken"
    exit 1
fi
if ! grep -qxF "${wt_candidate}" "${shallow_file}"; then
    echo "FAIL (case 4): expected ${wt_candidate} in .git/shallow"
    cat "${shallow_file}"
    exit 1
fi

WORKTREE="${TMP}/worktree"
git -C "${CLIENT}" worktree add --quiet --detach "${WORKTREE}" >/dev/null
wt_output="$(bash "${UNGRAFT}" -C "${WORKTREE}" --dry-run)"
# The fix (--git-common-dir) makes the script find the shared
# .git/shallow from the worktree and list the ungraftable entry.
# The bug (--absolute-git-dir) would resolve to
# .git/worktrees/<name>/shallow (nonexistent) and print
# "No candidate commits to ungraft".
if ! grep -qxF "Would ungraft ${wt_candidate}" <<< "${wt_output}"; then
    echo "FAIL (case 4): script did not see .git/shallow from linked worktree"
    echo "--- output ---"
    echo "${wt_output}"
    echo "--------------"
    exit 1
fi
echo "PASS (case 4): script reads .git/shallow from linked worktree"

echo "PASS: test_git_ungraft.sh"
