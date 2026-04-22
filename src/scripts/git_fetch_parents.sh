# shellcheck shell=bash
#
# Defines a `git_fetch_parents` shell function.
#
# Given a commit SHA (typically one at the shallow boundary), this
# function fetches each of the commit's parents into the local
# repository at `--depth=1`, so that the merge-commit case of a PR
# has both sides represented locally.  The fetched tip is landed
# under the private ref namespace
# `refs/fetch-through-merge-base/__github_parent__` (rather than a
# branch name that could collide with a user's branch) and is
# deleted immediately afterward via `git update-ref -d`.
#
# Parent discovery reads the raw commit object via `git cat-file -p`
# rather than a shallow-aware command such as `git show --format=%P`.
# Shallow-aware commands treat commits recorded in `.git/shallow` as
# if they had no parents — which is exactly the subset for which this
# function is meant to do useful work.  The awk filter emits only
# header-block `parent <sha>` lines (up to the first blank line),
# so commit-message body contents cannot be misparsed.
#
# This file is intended to be `source`d from other shell scripts;
# running it standalone does nothing.

git_fetch_parents() {
    local sha1="${1}"
    local parent_sha1
    local tmp_ref="refs/fetch-through-merge-base/__github_parent__"
    # awk sets `in_body` at the first blank line terminating the commit
    # header and then consumes the rest of the stream without printing.
    # Do NOT use `awk '/^$/ { exit }'`: under `set -o pipefail`, an
    # early-exit awk closes the read end of the pipe and causes
    # `git cat-file` to die of SIGPIPE when the commit body exceeds the
    # pipe buffer (~64 KB on Linux), aborting the script.
    for parent_sha1 in $(
        git cat-file -p "${sha1}" \
            | awk '
                in_body { next }
                /^$/ { in_body = 1; next }
                $1 == "parent" { print $2 }
            '
    ); do
        git fetch --update-head-ok --update-shallow --progress --quiet \
            --depth=1 origin "${parent_sha1}:${tmp_ref}"
        git update-ref -d "${tmp_ref}"
    done
}
