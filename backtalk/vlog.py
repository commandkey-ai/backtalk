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
"""Session log — terminal print + timestamped append to logs/backtalk.log.

Exists because the hardest voice bug ever hit here (the off-by-one
interrupt desync) had to be diagnosed from source, because the session
only printed to a terminal window nobody saved. Every load-bearing line
([you], replies, interrupts, drain/rebuild events, TTS fallbacks) goes
through log() so the next gremlin comes with receipts.
"""
import datetime
import os
import sys
from pathlib import Path

LOG_PATH = Path(__file__).resolve().parent.parent / "logs" / "backtalk.log"

# CommandKey AI: the log is a full conversation transcript, so on the
# systems that honour file modes (macOS, Linux) the folder is created
# 0700 and the file 0600: this user only, whatever the umask says. Windows
# has no such modes (chmod there only toggles read-only), so the files
# inherit the ACL of the folder they sit in; the backtalk folder lives in
# the user's own profile, which other standard accounts cannot read.
_LOG_DIR_MODE = 0o700
_LOG_FILE_MODE = 0o600
_perms_checked = False


def _restrict_perms():
    """Tighten the log folder and file once per process; best-effort."""
    global _perms_checked
    if _perms_checked or os.name != "posix":
        return
    _perms_checked = True
    for path, mode in ((LOG_PATH.parent, _LOG_DIR_MODE),
                       (LOG_PATH, _LOG_FILE_MODE)):
        try:
            if path.exists():
                os.chmod(path, mode)
        except OSError:
            pass


def _open_append():
    """Open the log for appending; a file created here starts 0600."""
    if os.name == "posix":
        fd = os.open(str(LOG_PATH), os.O_WRONLY | os.O_CREAT | os.O_APPEND,
                     _LOG_FILE_MODE)
        return os.fdopen(fd, "a", encoding="utf-8")
    return LOG_PATH.open("a", encoding="utf-8")

# CommandKey AI: size-based rotation. The log holds every utterance and
# every spoken reply, i.e. a complete conversation transcript, so it is
# bounded instead of growing forever: when backtalk.log passes ROTATE_AT
# bytes it becomes backtalk.log.1, .1 becomes .2, .2 becomes .3, and the
# oldest is dropped. At most ROTATE_KEEP + 1 files, roughly 20 MB total.
ROTATE_AT = 5 * 1024 * 1024
ROTATE_KEEP = 3


def _rotate_if_needed():
    """Shift the log files down one slot once the live log is too big.
    Checked on every write; a stat is cheap and a failure here must never
    take the voice down, so every step is best-effort."""
    try:
        if LOG_PATH.stat().st_size < ROTATE_AT:
            return
    except OSError:
        return
    try:
        oldest = LOG_PATH.with_name(f"{LOG_PATH.name}.{ROTATE_KEEP}")
        if oldest.exists():
            oldest.unlink()
        for i in range(ROTATE_KEEP - 1, 0, -1):
            src = LOG_PATH.with_name(f"{LOG_PATH.name}.{i}")
            if src.exists():
                src.replace(LOG_PATH.with_name(f"{LOG_PATH.name}.{i + 1}"))
        LOG_PATH.replace(LOG_PATH.with_name(f"{LOG_PATH.name}.1"))
    except OSError:
        pass


def _init_console():
    """Ask a Windows console for UTF-8 before anything is printed at it.

    Windows consoles default to a legacy codepage (cp1252 on a UK/US
    install), so a UTF-8 em-dash arrives as mojibake: the startup banner
    rendered as "[backtalk] up a<TM>" instead of "up --". Fixing the
    banner's own characters would not have been a fix, because the
    agent's REPLIES are printed here too and can contain anything at all.

    errors="replace" on the streams means a character the terminal
    genuinely cannot draw degrades to "?" rather than raising mid
    sentence and taking the voice down. No-ops everywhere but Windows.
    """
    if sys.platform != "win32":
        return
    try:
        import ctypes
        ctypes.windll.kernel32.SetConsoleOutputCP(65001)
        ctypes.windll.kernel32.SetConsoleCP(65001)
    except Exception:
        pass
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass


_init_console()


def log(line: str):
    try:
        print(line, flush=True)
    except UnicodeEncodeError:
        # Last resort if the console refused UTF-8: readable beats fatal.
        print(line.encode("ascii", "replace").decode("ascii"), flush=True)
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True, mode=_LOG_DIR_MODE)
        _restrict_perms()
        _rotate_if_needed()
        # encoding pinned on purpose. The default is the platform's, which
        # on Windows is that same legacy codepage -- so the log file kept
        # its own permanently corrupted copy of every line the console had
        # already mangled, and the receipts this module exists to produce
        # were unreadable exactly where they were most needed.
        with _open_append() as f:
            f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {line}\n")
    except Exception:
        pass  # a broken log file must never take the voice down
