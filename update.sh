#!/bin/bash
# backtalk — update to the current CommandKey AI release, showing what changed and asking first.
# Copyright (C) 2026 Jared Rhodenizer
# SPDX-License-Identifier: AGPL-3.0-or-later
# Modified by CommandKey AI, 2026-09-23 (see NOTICE-COMMANDKEY.md).
#
# Your backtalk.json is yours: nothing in this script can touch or overwrite it.
# Safe to run any time; when nothing is new it just says so.
#
# This script NEVER pulls a branch tip. It fetches the CommandKey AI
# mirror, reads the release name published in ES_RELEASE on the es-release
# branch, and checks out exactly that tag. A folder that arrived as a zip
# is wired to the mirror first, pinned to the release in its own ES_RELEASE.
# Before anything moves it checks that origin IS the CommandKey AI
# mirror, that the release name is of the form es-YYYY.MM.DD-rN, and that
# the tag carries its own name in its ES_RELEASE. It shows what is arriving
# and asks; `--yes` skips the question (for an agent running it).

main() {
  cd "$(dirname "$0")" || exit 1
  CFG="backtalk.json"
  MIRROR="https://github.com/commandkey-ai/backtalk"
  # Named explicitly: a `--depth 1 --branch <tag>` clone is single-branch,
  # so a bare fetch would never learn about es-release.
  REFSPEC="+refs/heads/es-release:refs/remotes/origin/es-release"
  # A release name is exactly es-YYYY.MM.DD-rN. Anything else read from a
  # file or from the mirror is refused before git ever sees it.
  RELEASE_RE='^es-[0-9]{4}\.[0-9]{2}\.[0-9]{2}-r[0-9]+$'
  YES=0
  for a in "$@"; do
    case "$a" in --yes|-y) YES=1 ;; esac
  done

  valid_release() { [[ "$1" =~ $RELEASE_RE ]]; }
  # True only when this folder fetches from the CommandKey AI mirror. A
  # different origin is reported and left alone, never re-pointed, with one
  # exact-string exception: an install made from release r1 or r2 carries
  # one of the mirror's retired organisation names (Executive-Stack-LLC,
  # then ExecutiveStack, renamed to commandkey-ai on 2026-10-01). Those
  # URLs, and only those, are moved to the current mirror once.
  origin_ok() {
    url="$(git remote get-url origin 2>/dev/null)"
    case "$url" in "https://github.com/Executive-Stack-LLC/backtalk"|"https://github.com/Executive-Stack-LLC/backtalk.git"|"https://github.com/ExecutiveStack/backtalk"|"https://github.com/ExecutiveStack/backtalk.git") git remote set-url origin "$MIRROR"; url="$(git remote get-url origin 2>/dev/null)" ;; esac
    [ "$url" = "$MIRROR" ] || [ "$url" = "$MIRROR.git" ]
  }
  # 0 fetched; 1 the mirror did not answer; 2 the mirror moved a tag this
  # folder already holds (git refuses that, and so do we: a published
  # release is never moved, a new one gets a new name).
  fetch_mirror() {
    err="$(git fetch --tags origin "$REFSPEC" 2>&1)" && return 0
    case "$err" in *clobber*) return 2 ;; esac
    return 1
  }
  # The tag exists AND the ES_RELEASE inside it names the tag itself.
  tag_checks_out() {
    valid_release "$1" || return 1
    git rev-parse -q --verify "refs/tags/$1^{commit}" >/dev/null 2>&1 || return 1
    [ "$(git show "refs/tags/$1:ES_RELEASE" 2>/dev/null | tr -d '[:space:]')" = "$1" ]
  }

  if [ ! -d .git ]; then
    # this folder arrived as a zip: wire it to the mirror, once, at the
    # release it arrived as, keeping the config
    PIN="$(tr -d '[:space:]' < ES_RELEASE 2>/dev/null)"
    if ! valid_release "$PIN"; then
      echo "no usable ES_RELEASE file here, so I cannot tell which release this is. Ask your CommandKey AI contact."
      exit 1
    fi
    [ -f "$CFG" ] && cp "$CFG" "$CFG.mine"
    git init -q -b main
    git remote add origin "$MIRROR"
    if origin_ok && fetch_mirror && tag_checks_out "$PIN"; then
      # No tracking branch on main, so a stray `git pull` has nowhere to go.
      git reset -q --hard "$PIN"
      echo "wired this folder to the mirror at $PIN."
    else
      rm -rf .git
      [ -f "$CFG.mine" ] && mv "$CFG.mine" "$CFG"
      echo "the mirror does not carry the tag $PIN; leaving this folder as it is. Ask your CommandKey AI contact."
      exit 1
    fi
    [ -f "$CFG.mine" ] && mv "$CFG.mine" "$CFG"
  fi

  if ! origin_ok; then
    echo "this folder gets its updates from '$(git remote get-url origin 2>/dev/null)', not from the CommandKey AI mirror; refusing to update it. Ask your CommandKey AI contact."
    exit 1
  fi
  fetch_mirror
  case $? in
    1) echo "could not reach the mirror (offline?); nothing changed."; exit 0 ;;
    2) echo "the mirror changed a release this folder already holds; refusing to trust it. Nothing changed. Ask your CommandKey AI contact."; exit 1 ;;
  esac
  CUR="$(tr -d '[:space:]' < ES_RELEASE 2>/dev/null)"
  NEW="$(git show origin/es-release:ES_RELEASE 2>/dev/null | tr -d '[:space:]')"
  if [ -z "$NEW" ]; then
    echo "the mirror has no published release name; nothing changed."
    exit 0
  fi
  if ! valid_release "$NEW"; then
    echo "the mirror names a release in a form this updater does not accept; nothing changed. Ask your CommandKey AI contact."
    exit 1
  fi
  if ! tag_checks_out "$NEW"; then
    echo "the mirror names release $NEW but that tag is missing or does not check out; nothing changed. Ask your CommandKey AI contact."
    exit 1
  fi
  if [ "$NEW" = "$CUR" ] && [ "$(git rev-parse HEAD)" = "$(git rev-parse "$NEW^{commit}")" ]; then
    echo "already on $CUR."
    exit 0
  fi
  git log --oneline "HEAD..$NEW" 2>/dev/null | sed "s/^/  new: /"
  if [ "$YES" != 1 ]; then
    printf 'Move to %s now? [y/N] ' "$NEW"
    read -r answer
    case "$answer" in y|Y|yes|YES) ;; *) echo "no changes made."; exit 0 ;; esac
  fi

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
