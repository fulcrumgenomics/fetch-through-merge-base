#!/bin/sh


DEEPEN_LENGTH=${DEEPEN_LENGTH:-10}
FAIL_AFTER=${FAIL_AFTER:-1000}

SCRIPT_DIR=$(dirname ${BASH_SOURCE[0]});

if [ -z "${GITHUB_HEAD_REF}" ]; then
  echo "Empty GITHUB_HEAD_REF!";
  exit 1;
fi
if [ -z "${GITHUB_BASE_REF}" ]; then
  echo "Empty GITHUB_BASE_REF!";
  exit 1;
fi
if [ -z "${DEEPEN_LENGTH}" ]; then
  echo "Empty DEEPEN_LENGTH!";
  exit 1;
fi
if [ -z "${FAIL_AFTER}" ]; then
  echo "Empty FAIL_AFTER!";
  exit 1;
fi

set -eou pipefail
set -x

function git_fetch_parents() {
    local sha1=${1};
    for parent_sha1 in $(git cat-file -p "${sha1}" | grep '^parent' | cut -f 2 -d ' '); do
        git fetch --update-head-ok --update-shallow --progress --depth=1 origin "${parent_sha1}:__github_parent__";
        git branch -D __github_parent__;
    done
}

# Fetch a branch or tag, and track it.  Do not fetch if a commit (yet).
if [[ "${GITHUB_BASE_REF}" != "$(git rev-parse --verify ${GITHUB_BASE_REF})" ]]; then
    git fetch --update-head-ok --update-shallow --progress --depth=1 origin "$GITHUB_BASE_REF:$GITHUB_BASE_REF";
fi
if [[ "${GITHUB_HEAD_REF}" != "$(git rev-parse --verify ${GITHUB_HEAD_REF})" ]]; then
    git fetch --update-head-ok --update-shallow --progress --depth=1 origin "$GITHUB_HEAD_REF:$GITHUB_HEAD_REF";
fi

# Fetch the references and track them in temporary branches.  Hopefully there are no collisions!
git fetch --progress --depth=1 --update-shallow origin "$GITHUB_BASE_REF:__github_base_ref__";
git fetch --progress --depth=1 --update-shallow origin "$GITHUB_HEAD_REF:__github_head_ref__";
GITHUB_BASE_REF=$(git rev-parse "__github_base_ref__");
GITHUB_HEAD_REF=$(git rev-parse "__github_head_ref__");

# For merge commits we need to fetch both parents  (e.g. from GitHub PRs)
git_fetch_parents "${GITHUB_BASE_REF}";
git_fetch_parents "${GITHUB_HEAD_REF}";
python ${SCRIPT_DIR}/git_ungraft.py;

# keep fetching deeper until we find the common ancestor reference
while [ -z "$( git merge-base "__github_base_ref__" "__github_head_ref__" )" ]; do
  # fetch deeper
  git fetch  --update-shallow --deepen="$DEEPEN_LENGTH" origin "$GITHUB_HEAD_REF";
  git fetch  --update-shallow --deepen="$DEEPEN_LENGTH" origin "$GITHUB_BASE_REF";
  python ${SCRIPT_DIR}/git_ungraft.py;
  # check if we are done iterating
  set +e;
  let FAIL_AFTER="FAIL_AFTER-1";
  set -e;
  if [ "$FAIL_AFTER" -le 0 ]; then
    echo "Failed to find the common ancestors of GITHUB_BASE_REF=${GITHUB_BASE_REF} and GITHUB_HEAD_REF=${GITHUB_HEAD_REF}";
    exit 1;
  else
    echo "Deepend search by ${DEEPEN_LENGTH}, ${FAIL_AFTER} iterations remaining...";
  fi
done

# cleanup
git branch -D __github_base_ref__ __github_head_ref__;
