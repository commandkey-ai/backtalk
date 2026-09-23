#!/bin/bash
# backtalk — update to the current Executive Stack release, showing what changed first.
# Copyright (C) 2026 Jared Rhodenizer
# SPDX-License-Identifier: AGPL-3.0-or-later
# Modified by Executive Stack, 2026-09-22 (see NOTICE-EXECUTIVE-STACK.md).
#
# Your backtalk.json is yours: nothing in this script can touch or overwrite it.
# Safe to run any time; when nothing is new it just says so.
#
# This script NEVER pulls a branch tip. It fetches the Executive Stack
# mirror, reads the release name published in ES_RELEASE on the es-release
# branch, and checks out exactly that tag. A folder that arrived as a zip
# is wired to the mirror first, pinned to the release in its own ES_RELEASE.

main() {
  cd "$(dirname "$0")" || exit 1
  CFG="backtalk.json"
  MIRROR="https://github.com/ES-MIRROR-ORG/backtalk"
  # Named explicitly: a `--depth 1 --branch <tag>` clone is single-branch,
  # so a bare fetch would never learn about es-release.
  REFSPEC="+refs/heads/es-release:refs/remotes/origin/es-release"

  if [ ! -d .git ]; then
    # this folder arrived as a zip: wire it to the mirror, once, at the
    # release it arrived as, keeping the config
    PIN="$(tr -d '[:space:]' < ES_RELEASE 2>/dev/null)"
    if [ -z "$PIN" ]; then
      echo "no ES_RELEASE file here, so I cannot tell which release this is. Ask your Executive Stack contact."
      exit 1
    fi
    [ -f "$CFG" ] && cp "$CFG" "$CFG.mine"
    git init -q -b main
    git remote add origin "$MIRROR"
    if git fetch -q --tags origin "$REFSPEC" && git rev-parse -q --verify "refs/tags/$PIN^{commit}" >/dev/null; then
      git reset -q --hard "$PIN"
      git branch -q --set-upstream-to=origin/es-release main 2>/dev/null
      echo "wired this folder to the mirror at $PIN."
    else
      rm -rf .git
      [ -f "$CFG.mine" ] && mv "$CFG.mine" "$CFG"
      echo "the mirror does not carry the tag $PIN; leaving this folder as it is. Ask your Executive Stack contact."
      exit 1
    fi
    [ -f "$CFG.mine" ] && mv "$CFG.mine" "$CFG"
  fi

  if ! git fetch -q --tags origin "$REFSPEC"; then
    echo "could not reach the mirror (offline?); nothing changed."
    exit 0
  fi
  CUR="$(tr -d '[:space:]' < ES_RELEASE 2>/dev/null)"
  NEW="$(git show origin/es-release:ES_RELEASE 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$NEW" ]; then
    echo "the mirror has no published release name; nothing changed."
    exit 0
  fi
  if ! git rev-parse -q --verify "refs/tags/$NEW^{commit}" >/dev/null; then
    echo "the mirror names release $NEW but does not carry that tag; nothing changed. Ask your Executive Stack contact."
    exit 1
  fi
  if [ "$NEW" = "$CUR" ] && [ "$(git rev-parse HEAD)" = "$(git rev-parse "$NEW^{commit}")" ]; then
    echo "already on $CUR."
    exit 0
  fi
  git log --oneline "HEAD..$NEW" 2>/dev/null | sed "s/^/  new: /"

  # one-time migration: the config moved out of git tracking. If git here
  # still tracks the old copy, lift yours aside, let the checkout retire the
  # tracked one, then put yours back exactly as it was.
  MIGRATE=0
  if git ls-files --error-unmatch "$CFG" >/dev/null 2>&1 && [ -f "$CFG" ]; then
    cp "$CFG" "$CFG.mine" && git checkout -q -- "$CFG" && MIGRATE=1
  fi

  # The tag is the only thing ever checked out; main is moved onto it so
  # the folder never sits on a detached HEAD.
  git checkout -q -B main "$NEW" && echo "now on $NEW." || echo "  (couldn't move to $NEW; your local edits win.)"

  if [ "$MIGRATE" = 1 ] && [ -f "$CFG.mine" ]; then
    mv "$CFG.mine" "$CFG"
  fi
  echo "update complete."
}
main "$@"
