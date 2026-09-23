<!-- Added by Executive Stack, 2026-09-22. See NOTICE-EXECUTIVE-STACK.md. -->
# Model weights manifest (Executive Stack release es-2026.09.23-r1)

backtalk downloads about 1 GB of model weights from the Hugging Face Hub on first run. Upstream fetched whatever each repository's `main` branch held that day. This release pins every weight to the exact Hub commit it was reviewed with, listed here, and says plainly which pins are enforced in code and which are not.

Commits were read from the Hub API (`https://huggingface.co/api/models/<repo>`, field `sha`) on 2026-09-22. No weights were downloaded to build this manifest.

## Pinned IN CODE

| Model | Hub repository | Pinned commit | How it is enforced |
|---|---|---|---|
| Speech-to-text, `small.en` (default) | `Systran/faster-whisper-small.en` | `d1d751a5f8271d482d14ca55d9e2deeebbae577f` | `backtalk/ears.py` passes `revision=` to `faster_whisper.WhisperModel` (faster-whisper 1.2.1 in `uv.lock`), which hands it to `huggingface_hub`; only that snapshot can be downloaded. |
| Speech-to-text, `tiny.en` | `Systran/faster-whisper-tiny.en` | `0d3d19a32d3338f10357c0889762bd8d64bbdeba` | same |
| Speech-to-text, `base.en` | `Systran/faster-whisper-base.en` | `3d3d5dee26484f91867d81cb899cfcf72b96be6c` | same |
| Speech-to-text, `medium.en` | `Systran/faster-whisper-medium.en` | `a29b04bd15381511a9af671baec01072039215e3` | same |
| Text-to-speech (built-in voice) | `hexgrad/Kokoro-82M` | `f3ff3571791e39611d31c381e3a41a3af07b4987` | `kokoro.KPipeline` (kokoro 0.9.4) has no revision argument and calls `huggingface_hub.hf_hub_download` without one, so `backtalk/mouth.py` (`_pin_kokoro_downloads`) replaces the `hf_hub_download` name bound in `kokoro.model` and `kokoro.pipeline` with a wrapper that adds `revision=` for this repository only. The log line `kokoro weights pinned to hexgrad/Kokoro-82M@f3ff3571791e` confirms it took effect; if the library layout ever changes the log says the pin did not apply and the offline route below is the fallback. |

The pins live in `backtalk/config.py` (`stt_model_revisions`, `tts_model_revision`) and can be overridden in `backtalk.json`. A `stt_model` name with no entry loads the Hub's current revision and logs that it is unpinned.

## NOT pinned in code (manifest only)

| Model | Hub repository | Reviewed commit | Why not in code |
|---|---|---|---|
| Speech-to-text on Apple Silicon, `small.en` | `mlx-community/whisper-small.en-mlx` | `52a88bf6e98b114a210c21bb83e22d6e1505cb73` | `mlx_whisper.transcribe(path_or_hf_repo=...)` (mlx-whisper 0.4.3) takes a repository name and loads it through `huggingface_hub.snapshot_download` with no revision argument. Its signature could not be verified on the build machine (mlx is macOS-only), so no code change was made. Pre-seed instead (below). |
| `tiny.en` (Apple Silicon) | `mlx-community/whisper-tiny.en-mlx` | `5f4dafbb28e62a53c1b10426ff7eed36ca733bf7` | same |
| `base.en` (Apple Silicon) | `mlx-community/whisper-base.en-mlx` | `aa0678c3466ed62c5c6114ec600a0e1f96820089` | same |
| `medium.en` (Apple Silicon) | `mlx-community/whisper-medium.en-mlx` | `8d0335069b551e8586b8a4680674403d9417dfe4` | same |

## Pre-seed and offline route (Apple Silicon, or any fleet install)

For a client machine that must never resolve a model on the Hub itself:

1. On a trusted machine, download each snapshot at its reviewed commit into a Hugging Face cache, for example with `huggingface-cli download <repo> --revision <commit>` (this writes `~/.cache/huggingface/hub/models--<org>--<name>/snapshots/<commit>/`).
2. Copy that cache directory to the client (same path, or set `HF_HOME` to wherever it lands).
3. Set `HF_HUB_OFFLINE=1` in the environment the voice line launches from (the Desktop launcher is the right place). With that set, `huggingface_hub` serves only what is already in the cache and refuses to contact the Hub, so an unpinned call (the MLX path) can only ever load the seeded snapshot.
4. Keep a `sha256sum` (or `Get-FileHash`) listing of the seeded snapshot directories with the fleet's install records.

## Where the weights live on a client machine

`~/.cache/huggingface/hub/` (macOS, Linux) or `%USERPROFILE%\.cache\huggingface\hub\` (Windows), unless `HF_HOME` is set. Snapshot folders are named by the exact commit, so `ls models--Systran--faster-whisper-small.en/snapshots/` shows which revision a machine actually has.
