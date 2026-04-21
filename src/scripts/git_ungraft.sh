#!/usr/bin/env bash
#
# git_ungraft.sh — bash port of git_ungraft.py
#
# Investigates commits listed in .git/shallow and removes those whose
# parents are all present locally (i.e. no longer need to be marked as
# shallow).
#
# Original Python implementation:
#   https://github.com/chrillof/git-ungraft
#   Commit 0e13deca4466667d50cc8b7127314d6d71f97c9e
#   MIT License, Copyright (c) 2023 Christoffer Calås
#
# Local modifications:
# - ported to bash (no Python dependency)
# - do not overwrite .git/shallow if the set of grafted commits is
#   unchanged
#
# NOTE: we cannot use `git show --format=%P` or any other shallow-aware
# parent-listing command here, because git treats commits listed in
# .git/shallow as if they had no parents — which is exactly the subset
# we are trying to re-evaluate.  `git cat-file -p` reads the raw commit
# object and is therefore the only reliable way to recover the true
# parent list.  We scan only the header block (up to the first blank
# line) so that commit-message body contents cannot be misparsed as
# "parent <sha>" lines.
#
# LICENSE (from the original):
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

set -euo pipefail

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") [-n|--dry-run] [-C|--git-dir PATH]

  -n, --dry-run        Print what would be ungrafted; do not modify .git/shallow.
  -C, --git-dir PATH   Run as if git was started in PATH (default: .).
  -h, --help           Show this message.
EOF
}

dry_run=0
work_dir=.
while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run) dry_run=1; shift ;;
        -C|--git-dir) work_dir="$2"; shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

if ! git_dir="$(git -C "$work_dir" rev-parse --git-dir 2>/dev/null)"; then
    echo "The path ${work_dir} is not within a git repository" >&2
    exit 1
fi
# Normalize to absolute so later lookups don't depend on cwd.
git_dir="$(cd "$work_dir" && cd "$git_dir" && pwd)"
shallow_file="${git_dir}/shallow"

if [ ! -f "$shallow_file" ]; then
    echo "No candidate commits to ungraft"
    exit 0
fi

candidates=()
remaining=()
while IFS= read -r sha || [ -n "$sha" ]; do
    [ -z "$sha" ] && continue
    all_present=1
    # Read the raw commit object and emit only parent-header SHAs from
    # the header block (awk exits on the first blank line, which
    # terminates the header and begins the commit message body).
    parents="$(git -C "$work_dir" cat-file -p "$sha" \
        | awk '/^$/ { exit } $1 == "parent" { print $2 }')"
    for parent in $parents; do
        if ! git -C "$work_dir" cat-file -e "${parent}^{commit}" 2>/dev/null; then
            all_present=0
            break
        fi
    done
    if [ "$all_present" -eq 1 ]; then
        candidates+=("$sha")
    else
        remaining+=("$sha")
    fi
done < "$shallow_file"

# Only rewrite when the set actually changed (preserve mtime on no-op).
if [ "$dry_run" -eq 0 ] && [ "${#candidates[@]}" -gt 0 ]; then
    tmp="${shallow_file}.tmp"
    if [ "${#remaining[@]}" -gt 0 ]; then
        printf '%s\n' "${remaining[@]}" > "$tmp"
    else
        : > "$tmp"
    fi
    mv "$tmp" "$shallow_file"
fi

prefix="Ungrafted "
[ "$dry_run" -eq 1 ] && prefix="Would ungraft "
if [ "${#candidates[@]}" -gt 0 ]; then
    for candidate in "${candidates[@]}"; do
        echo "${prefix}${candidate}"
    done
else
    echo "No candidate commits to ungraft"
fi
