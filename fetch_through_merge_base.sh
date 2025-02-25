#!/bin/sh


DEEPEN_LENGTH=${DEEPEN_LENGTH:-10}
FAIL_AFTER=${FAIL_AFTER:-1000}

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

set -x
set -eou pipefail

# fetch the references and track them in temporary branches.  Hopefully there are no collisions!
git fetch --progress --depth=1 origin "$GITHUB_BASE_REF:__github_base_ref__";
git fetch --progress --depth=1 origin "$GITHUB_HEAD_REF:__github_head_ref__";

# keep fetching deeper until we find the common ancestor reference
while [ -z "$( git merge-base "__github_base_ref__" "__github_head_ref__" )" ]; do
  # fetch deeper
  git fetch --deepen="$DEEPEN_LENGTH" origin "$GITHUB_HEAD_REF";
  git fetch --deepen="$DEEPEN_LENGTH" origin "$GITHUB_BASE_REF";
  # check if we are done iterating
  let FAIL_AFTER="FAIL_AFTER-1";
  if [ "$FAIL_AFTER" -le 0 ]; then
    echo "Failed to find the common ancestors of GITHUB_BASE_REF=${GITHUB_BASE_REF} and GITHUB_HEAD_REF=${GITHUB_HEAD_REF}";
    if [[ "$FALLBACK_FETCH_ALL" == "false" ]]; then
      exit 1;
    fi
    echo "Falling back to fetching all references";
    git fetch --all;
  else
    echo "Deepend search by ${DEEPEN_LENGTH}, ${FAIL_AFTER} iterations remaining...";
  fi
done

# cleanup
git branch -D __github_base_ref__ __github_head_ref__;
