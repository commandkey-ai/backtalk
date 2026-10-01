#!/bin/bash
# backtalk: talk to your Claude Code agent out loud.
# Copyright (C) 2026 Jared Rhodenizer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-or-later
# Modified by CommandKey AI, 2026-09-23 (see NOTICE-COMMANDKEY.md).
# backtalk installer — environment, engines, models. Run once.
# Safe to re-run; every step skips what's already done.
set -e
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

echo "== backtalk install (CommandKey AI release $(tr -d '[:space:]' < ES_RELEASE 2>/dev/null)) =="

# --- uv (the Python environment manager), PINNED ---
# CommandKey AI policy: no curl-pipe-sh. uv is installed from one exact
# GitHub release asset whose SHA-256 is written here, and the download is
# refused if the hash does not match. To move to a newer uv, change all
# three of UV_VERSION and the two hashes below in the same edit.
#
# The pinned uv is the ONLY uv this install and run.sh ever use. It lives
# at UV_MANAGED, side by side with whatever uv the machine already has
# (which is never touched, never shadowed, and never used unless it is
# exactly the pinned version). No PATH edits: every launcher calls the
# managed copy by its absolute path.
UV_VERSION="0.12.18"
UV_MANAGED_DIR="$HOME/.local/share/commandkey/uv"
UV_MANAGED="$UV_MANAGED_DIR/uv"
uv_expected_sha() {
  case "$1" in
    aarch64-apple-darwin)      echo "cf40e0c6a202190ccd9e0406dcfdd5b2d6668a9a5c779b17948963df32aafe5b" ;;
    x86_64-apple-darwin)       echo "2e4108f5395397c8bc5d43bf83d3bdbb2d0e92b90d0efa607756be704905fa33" ;;
    x86_64-unknown-linux-gnu)  echo "89eadd7c76fc063887959510d5ba0ab1264dfd5f1143b925ddb73021a40acf16" ;;
    aarch64-unknown-linux-gnu) echo "afb6291f3f0a6b4521fc67b947822506c41dde5b60d2189dd8f3695b2ac8c9e7" ;;
    *) echo "" ;;
  esac
}
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}
install_pinned_uv() {
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)  target="aarch64-apple-darwin" ;;
    Darwin-x86_64) target="x86_64-apple-darwin" ;;
    Linux-x86_64)  target="x86_64-unknown-linux-gnu" ;;
    Linux-aarch64|Linux-arm64) target="aarch64-unknown-linux-gnu" ;;
    *) echo "   no pinned uv build for $(uname -s)/$(uname -m). Ask your CommandKey AI contact."; exit 1 ;;
  esac
  want="$(uv_expected_sha "$target")"
  asset="uv-$target.tar.gz"
  url="https://github.com/astral-sh/uv/releases/download/$UV_VERSION/$asset"
  tmp="$(mktemp -d)"
  echo "   downloading uv $UV_VERSION ($target) and checking its SHA-256"
  curl -LsSf -o "$tmp/$asset" "$url"
  got="$(sha256_of "$tmp/$asset")"
  if [ "$got" != "$want" ]; then
    rm -rf "$tmp"
    echo "   uv download HASH MISMATCH (expected $want, got $got). Refusing to install. Ask your CommandKey AI contact."
    exit 1
  fi
  mkdir -p "$UV_MANAGED_DIR"
  tar -xzf "$tmp/$asset" -C "$tmp"
  cp "$tmp/uv-$target/uv" "$tmp/uv-$target/uvx" "$UV_MANAGED_DIR/"
  chmod +x "$UV_MANAGED_DIR/uv" "$UV_MANAGED_DIR/uvx"
  rm -rf "$tmp"
  if ! uv_is_pinned "$UV_MANAGED"; then
    echo "   the installed uv does not report version $UV_VERSION. Refusing to continue. Ask your CommandKey AI contact."
    exit 1
  fi
  echo "   uv $UV_VERSION installed to $UV_MANAGED_DIR"
}
uv_is_pinned() { [ -x "$1" ] && [ "$("$1" --version 2>/dev/null | cut -d' ' -f2)" = "$UV_VERSION" ]; }
if uv_is_pinned "$UV_MANAGED"; then
  UV="$UV_MANAGED"
  echo "-- uv $UV_VERSION: the CommandKey AI managed copy at $UV_MANAGED"
elif command -v uv >/dev/null 2>&1 && uv_is_pinned "$(command -v uv)"; then
  UV="$(command -v uv)"
  echo "-- uv $UV_VERSION: already on PATH at $UV"
else
  if command -v uv >/dev/null 2>&1; then
    echo "-- uv on PATH is '$(uv --version 2>/dev/null)', not the pinned $UV_VERSION this release was resolved and tested with."
    echo "   Installing the pinned uv side by side at $UV_MANAGED (yours is not touched)."
  else
    echo "-- uv not found. It's the fast Python manager this uses."
    read -r -p "   Install the pinned uv $UV_VERSION now? [Y/n] " a
    if [ "$a" = "n" ] || [ "$a" = "N" ]; then
      echo "   Install uv $UV_VERSION yourself and re-run."
      exit 1
    fi
  fi
  install_pinned_uv
  UV="$UV_MANAGED"
fi

# --- espeak-ng (the one system library: the voice engine phonemizes
#     through it; its pip-bundled build is broken, the system package is
#     the supported path) ---
if ! command -v espeak-ng >/dev/null 2>&1 && \
   [ ! -e /opt/homebrew/lib/libespeak-ng.dylib ] && \
   [ ! -e /usr/local/lib/libespeak-ng.dylib ] && \
   [ ! -e /usr/lib/x86_64-linux-gnu/libespeak-ng.so.1 ]; then
  echo "-- installing espeak-ng (the voice engine needs it)"
  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then brew install espeak-ng
      else echo "   Homebrew not found — install it (https://brew.sh), then re-run."; exit 1; fi ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then sudo apt-get install -y espeak-ng
      elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y espeak-ng
      elif command -v pacman >/dev/null 2>&1; then sudo pacman -S --noconfirm espeak-ng
      else echo "   Install espeak-ng with your package manager, then re-run."; exit 1; fi ;;
    *) echo "   Unknown platform — install espeak-ng manually, then re-run."; exit 1 ;;
  esac
else
  echo "-- espeak-ng: already present"
fi

# --- Linux audio headers (sounddevice needs PortAudio) ---
if [ "$(uname -s)" = "Linux" ] && ! ldconfig -p 2>/dev/null | grep -q portaudio; then
  echo "-- installing PortAudio (mic + speaker access)"
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y libportaudio2 portaudio19-dev
  fi
fi

# --- the Python environment, from the COMMITTED lockfile ---
# --frozen installs exactly what uv.lock says and never re-resolves
# against PyPI. --python 3.12 keeps every machine on the same interpreter
# line (uv fetches a managed build if none is present; uv verifies those
# downloads against hashes baked into the pinned uv binary).
echo "-- creating the environment (first run downloads ~900MB of packages)"
"$UV" sync -q --frozen --python 3.12

# --- prefetch the models so the first conversation doesn't wait ---
if [ "$1" != "--no-models" ]; then
  echo "-- downloading the speech models (first run only, ~1GB total)"
  .venv/bin/python - <<'PY'
import warnings; warnings.filterwarnings("ignore")
from backtalk.ears import warm as warm_ears
from backtalk.mouth import warm as warm_mouth
warm_ears()
warm_mouth()
print("-- models ready")
PY
fi

echo ""
echo "== backtalk installed =="
echo ""
echo "uv in use: $UV (run.sh finds it by itself)"
echo ""
echo "Next:"
echo "  1. Point it at your agent: edit backtalk.json (agent_dir + name),"
echo "     or open this folder in Claude Code and say:"
echo "         read backtalk.md and set me up"
echo "  2. ./run.sh — hold the key, talk, let go."
echo ""
echo "macOS: the FIRST run will ask for Microphone permission, and the"
echo "hold-to-talk key needs Input Monitoring for your terminal app"
echo "(System Settings -> Privacy & Security -> Input Monitoring)."
