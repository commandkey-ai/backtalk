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
# backtalk entrypoint — start a spoken conversation with your agent.
# Terminal-invoked (inherits the terminal's mic permission). Ctrl-C hangs up.
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
# WSL2 self-heal. PortAudio's ALSA pulse plugin looks for the socket at
# the standard runtime path whatever $PULSE_SERVER says, and WSLg only
# creates it at /mnt/wslg/PulseServer. Without this link, playback does
# not fail cleanly: it CRASHES the process with a core dump, which reads
# as the voice line being broken rather than the audio path being
# unwired. That runtime folder is wiped on every reboot, so the link is
# remade on every launch rather than once at install.
#
# Guarded on the socket existing, so this is a no-op on every platform
# that is not WSL2.
if [ -S /mnt/wslg/PulseServer ] && [ ! -S "/run/user/$(id -u)/pulse/native" ]; then
  mkdir -p "/run/user/$(id -u)/pulse"
  ln -sf /mnt/wslg/PulseServer "/run/user/$(id -u)/pulse/native"
fi
# Single-instance guard: a stale voice session left in a background
# terminal answers the same mic alongside a fresh launch = two voices at
# once, and it sounds haunted. One body, one mouth.
if pkill -f "backtalk[.]main" 2>/dev/null; then
  echo "[backtalk] replaced a previous voice session"
  sleep 1   # let the old process release mic/speaker devices
fi
# One pinned uv, and only that one: the CommandKey AI managed copy that
# install.sh places at UV_MANAGED, or a uv already on PATH only when it is
# exactly the pinned version. Any other uv is refused, because the
# lockfile was resolved and tested with this one.
UV_PIN="0.12.18"
UV_MANAGED="$HOME/.local/share/commandkey/uv/uv"
uv_is_pinned() { [ -x "$1" ] && [ "$("$1" --version 2>/dev/null | cut -d' ' -f2)" = "$UV_PIN" ]; }
if uv_is_pinned "$UV_MANAGED"; then UV="$UV_MANAGED"
elif command -v uv >/dev/null 2>&1 && uv_is_pinned "$(command -v uv)"; then UV="$(command -v uv)"
else
  echo "[backtalk] the voice line needs uv $UV_PIN and found '$(uv --version 2>/dev/null || echo none)'; refusing to launch. Run ./install.sh, which puts the pinned uv at $UV_MANAGED." >&2
  exit 1
fi
# Self-repair: reconcile the environment with the COMMITTED lockfile
# before launching (sub-second when already current). --frozen installs
# exactly what uv.lock says and never re-resolves against PyPI, so every
# machine on this release runs the same reviewed package set; a missing
# package (a half-finished install, a drifted env) heals here instead of
# crashing on import. Fails CLOSED: if the locked environment cannot be
# verified, the voice line does not launch on whatever happens to be
# installed. Offline with an intact environment is still a valid launch,
# which is what the --offline retry is for (it verifies against the
# lockfile without the network; a missing package still fails it).
if ! "$UV" sync -q --frozen; then
  echo "[backtalk] could not verify the locked environment online; checking offline" >&2
  if ! "$UV" sync -q --frozen --offline; then
    echo "[backtalk] the locked Python environment could not be verified (the uv output above says why); refusing to launch. Run ./install.sh, or ask your CommandKey AI contact." >&2
    exit 1
  fi
fi
exec "$UV" run --frozen python -m backtalk.main "$@" 2> >(grep -vi "pkg_resources\|VIRTUAL_ENV" >&2)
