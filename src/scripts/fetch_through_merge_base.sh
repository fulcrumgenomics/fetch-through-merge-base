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

# Fetch a branch or tag, and track it.  Do not fetch if a commit (yet).
if [[ "${GITHUB_BASE_REF}" != "$(git rev-parse --verify ${GITHUB_BASE_REF})" ]]; then
    git fetch --update-head-ok --progress --quiet --depth=1 origin "$GITHUB_BASE_REF:$GITHUB_BASE_REF";
fi
if [[ "${GITHUB_HEAD_REF}" != "$(git rev-parse --verify ${GITHUB_HEAD_REF})" ]]; then
    git fetch --update-head-ok --progress --quiet --depth=1 origin "$GITHUB_HEAD_REF:$GITHUB_HEAD_REF";
fi

# Fetch the references and track them in temporary branches.  Hopefully there are no collisions!
git fetch --progress --quiet --depth=1 origin "$GITHUB_BASE_REF:__github_base_ref__";
git fetch --progress --quiet --depth=1 origin "$GITHUB_HEAD_REF:__github_head_ref__";
GITHUB_BASE_REF=$(git rev-parse "__github_base_ref__");
GITHUB_HEAD_REF=$(git rev-parse "__github_head_ref__");

# keep fetching deeper until we find the common ancestor reference
while [ -z "$( git merge-base "__github_base_ref__" "__github_head_ref__" )" ]; do
  # fetch deeper
  git fetch  --quiet --deepen="$DEEPEN_LENGTH" origin "$GITHUB_HEAD_REF";
  git fetch  --quiet --deepen="$DEEPEN_LENGTH" origin "$GITHUB_BASE_REF";
  python ${SCRIPT_DIR}/git_ungraft.py;
  # check if we are done iterating
  set +e;
  let FAIL_AFTER="FAIL_AFTER-1";
  set -e;
  if [ "$FAIL_AFTER" -le 0 ]; then
    echo "Failed to find the common ancestors of GITHUB_BASE_REF=${GITHUB_BASE_REF} and GITHUB_HEAD_REF=${GITHUB_HEAD_REF}";
    if [[ "$FALLBACK_FETCH_ALL" == "false" ]]; then
      exit 1;
    fi
    echo "Falling back to fetching all references";
    git fetch --quiet --all;
    python ${SCRIPT_DIR}/git_ungraft.py;
    break;
  else
    echo "Deepend search by ${DEEPEN_LENGTH}, ${FAIL_AFTER} iterations remaining...";
  fi
done

# cleanup
git branch -D __github_base_ref__ __github_head_ref__;
