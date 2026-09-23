# Notice of modification (AGPL-3.0 section 5(a))

This is a **modified version** of `backtalk` by Jared Rhodenizer (upstream: https://github.com/jaredrhod/backtalk), prepared by **Executive Stack** and dated **2026-09-22**.

- Based on upstream commit: `84b3a6cd321060cabb74aad6ebe794621cf99bd3` (upstream author `jaredrhod`, dated 2026-08-30).
- Executive Stack release: `es-2026.09.23-r1` (the name in `ES_RELEASE`), on branch `es-release`.
- License: unchanged, GNU Affero General Public License v3.0 or later. The `LICENSE` file, every copyright line, and every `SPDX-License-Identifier` header are intact. Source for this modified version is the mirror repository itself.
- Each modified source file carries a "Modified by Executive Stack, 2026-09-22" line near its SPDX header (or an HTML comment at the top of Markdown files). Files added by Executive Stack say "Added by Executive Stack".
- Not included on purpose: a local, uncommitted change on the build machine that lowered the playback prebuffer from 0.75 s to 0.25 s. This release keeps upstream's 0.75 s (`backtalk/mouth.py`, `_play_stream`).

## Why

Executive Stack ships this software to its clients from a reviewed, pinned mirror. The changes below (1) make the Python environment reproducible (a committed lockfile, `uv sync --frozen`, a pinned and hash-checked `uv`), (2) pin the speech-model weights to reviewed Hugging Face commits, (3) give Windows a scripted installer instead of improvised steps, (4) make every install and update path land on the reviewed release tag, (5) close the by-voice route into auto-approve on client machines, (6) bound the on-disk transcript log, and (7) replace the author's community and marketing material with the Executive Stack support pointer (author attribution and license credit are kept).

## Files changed, and why

| File | Change |
|---|---|
| `.gitignore` | `uv.lock` is no longer ignored; the lockfile is committed. |
| `uv.lock` | New: the universal lockfile (`uv lock`, uv 0.12.15, 157 packages, all from the PyPI registry) that every launcher installs with `--frozen`. |
| `README.md` | Install commands point at the mirror at the release tag; describes the lockfile, the pinned uv and the model pins; Windows section points at `install.ps1`; the by-voice auto-approve switch documented as disabled by default; log rotation and retention documented; barehands removed; the author's video-voice reference, YouTube, Discord and Ko-fi replaced with the Executive Stack support pointer; stale "ninety-one lines" corrected; license section keeps the author's copyright and adds the modification notice. |
| `TROUBLESHOOTING.md` | `uv sync` fixes use `--frozen`; update entry describes the pinned-tag update; permission entries describe the closed by-voice switch; new log retention entry; Windows notes point at `install.ps1` and pinned espeak-ng 1.52.0; ffmpeg winget pinned to 9.0.2; architecture note updated; barehands reference removed. |
| `backtalk.md` | Byline carries upstream and mirror; Windows lane (Phase 1 step 3) now runs the shipped `install.ps1` instead of `irm ... \| iex`, unpinned winget and `uv pip install -e .`; ffmpeg winget pinned; the author's video-voice reference removed; ai-visualizer pointer moved to the mirror, barehands removed; permissions phase describes the closed by-voice switch; the test-fire checklist adds the refusal check; Phase 5.5 drops barehands and points the fullstack-agent one-liners at the mirror at the tag with the hash-checked Windows zip; Discord and YouTube replaced with the support pointer; the Windows launcher uses `uv sync -q --frozen`; update wording describes the pinned-tag update; log retention mentioned in the handover. |
| `install.sh` | `curl \| sh` replaced with a pinned uv (0.12.18) downloaded from its GitHub release asset and verified against SHA-256 values written in the script; `uv venv` + `uv pip install -e .` replaced with `uv sync --frozen --python 3.12`. |
| `install.ps1` | New: the scripted Windows installer (pinned, hash-checked uv 0.12.18; `winget install --id eSpeak-NG.eSpeak-NG --version 1.52.0`; `uv sync --frozen --python 3.12`; model prefetch). |
| `run.sh` | `uv sync -q --inexact` replaced with `uv sync -q --frozen`. |
| `update.sh` | Rewritten to update only to the release tag published in `ES_RELEASE` on the mirror's `es-release` branch (never `origin/main` or `git pull`); a zip-installed folder is wired to the mirror pinned to its own `ES_RELEASE`. |
| `update.bat` | The comment block now gives the mirror/tag commands instead of the upstream remote and `reset --hard origin/main`; the spoken update phrase updated. |
| `backtalk/config.py` | New keys: `allow_voice_bypass` (default false), `stt_model_revisions` (pinned Hub commits per faster-whisper model), `tts_model_revision` (pinned Kokoro commit); the unused hands-seam comment no longer points at an upstream repository. |
| `backtalk/ears.py` | `WhisperModel(...)` is called with `revision=` from `stt_model_revisions` (both the primary and the CPU-fallback construction); new `_stt_revision()` helper; MLX note. |
| `backtalk/mouth.py` | New `_pin_kokoro_downloads()` pins kokoro's `hf_hub_download` calls to `tts_model_revision` for `hexgrad/Kokoro-82M`; `KPipeline` is given `repo_id` explicitly. |
| `backtalk/main.py` | The spoken `noask` verb (and its confirm) answers "not available on this install" and changes nothing unless `allow_voice_bypass` is true; the permission gate no longer advertises the phrase when the switch is closed. |
| `backtalk/vlog.py` | Size-based log rotation: `logs/backtalk.log` rotates at 5 MB, keeping three old copies. |
| `MODELS.lock.md` | New: the model-weights manifest (pinned commits, which pins are enforced in code, the pre-seed / `HF_HUB_OFFLINE` route for the MLX path). |
| `ES_RELEASE` | New: the release tag name this checkout belongs to. |
| `NOTICE-EXECUTIVE-STACK.md` | New: this notice. |

Files not listed (including `pyproject.toml`, `brain.py`, `ducking.py`, `ptt.py`, `signals.py`, `__init__.py`, `assets/thinking.wav`, `backtalk.json.example`, `CONTRIBUTING.md`, `LICENSE`, `.gitattributes`) are byte-for-byte identical to the upstream commit.
