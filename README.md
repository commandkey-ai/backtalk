<!-- Modified by Executive Stack, 2026-09-23. See NOTICE-EXECUTIVE-STACK.md. -->
# backtalk (Executive Stack release)

> **This is the Executive Stack pinned release** of Jared Rhodenizer's backtalk. It installs from a committed lockfile, pins its model weights (see `MODELS.lock.md`), and updates only to release tags Executive Stack has published. Support: your Executive Stack contact.

**Runs on:** Claude Code only; the voice is built on Claude's agent SDK. The $20 Pro plan is enough.

Talk to your Claude Code agent out loud. Hold a key, say the thing, and it answers through your speakers in a real voice about a second later, with all its tools, your project context, and its own personality. Your AI finally has something to say back.

The hearing and the voice run local: free, offline models on your machine, no voice API keys, no per-word costs. The brain is the Claude Code you already have. On a Claude subscription, talking works like any other session and uses your plan's usage, with nothing extra to buy. It ships as working code, so your agent's job is pointing it at your setup, not building it from scratch.

## What it does

- **Hold a key, talk, release.** Your words are transcribed locally and handed to a live Claude Code session. The reply is spoken sentence by sentence as it's generated, with first audio in about 1 to 2 seconds on warm turns. Prefer no button at all? **Hands-free listening** is one spoken sentence away ("go hands free"), and the key keeps working there as your interrupt.
- **It's YOUR agent talking.** The session runs in the folder whose CLAUDE.md defines your assistant: same name, same personality, same memory as your terminal sessions. backtalk has no personality of its own; it's a mouth and ears for whoever you already have. (No agent yet? The [ai-memory-vault](https://github.com/Executive-Stack-LLC/ai-memory-vault) build ships with a professional default identity, ready to use.)
- **Interrupt it.** Press the key while it's talking and it shuts up and listens. No headphones needed, because the mic only opens while you hold the key, so it never hears the speakers.
- **Type instead whenever you want.** Typing in the terminal is the same conversation, and the reply is still spoken.
- **It asks before it acts, in plain words.** When your agent wants to do something real, it asks out loud the way a person would ("I want to change a note in your vault called Recipes") and waits. An exact spoken yes approves; "details" reads you the exact command; anything else denies, with your words passed back as the reason, so "no, put that in drafts instead" actually steers it. Most read-only work passes without interrupting. On an Executive Stack install the spoken "stop asking for permission" switch is closed by default (`allow_voice_bypass` in the config): saying it gets a polite "not available on this install" and changes nothing. Auto-approve, where it belongs on a machine, is set in the config file by your agent, and takes effect at the next launch.
- **The voice console.** Session control by voice, so you never go back to the keyboard: "clear the session", "compact the session", "switch to the deep model" / "back to the fast model", "set effort to low" (or medium, high, max; this one saves itself as your default), "usage report", "go hands free" / "push to talk mode" for the microphone, "start asking again" for approvals. Exact phrases, spoken alone. (Credit where due: this grew out of a community member's own build shared with the upstream author.)
- **It can pick up where it left off.** Set `"resume_last_session": true` in the config and every launch reattaches to your previous conversation instead of starting cold, so closing the window stops costing you the thread. Off by default. And the built-in voice has a pace dial: `"speed"` in the config, 1.0 native, 1.15 brisker. (Credit where due: both grew out of a community proposal by aram-cloudstak.)
- **Music ducks while it speaks** (Spotify, macOS) and comes back up after.
- **It thinks out loud.** While the agent works, you hear a processing sound, so a pause never reads as a dead line. Silence it with `"thinking_sound": ""` in the config.

## Install

```
git clone --branch es-2026.09.23-r1 --depth 1 https://github.com/Executive-Stack-LLC/backtalk
cd backtalk
./install.sh
```

The installer sets up a Python environment from the committed `uv.lock` (`uv sync --frozen`, never a fresh resolution), the two local AI models (speech-to-text and the voice, at the revisions pinned in `MODELS.lock.md`), and the one system library they need. First run downloads the models (about 1 GB total); everything after is instant. Prerequisites: [Claude Code](https://claude.com/claude-code) with a Claude subscription. `uv` is handled by the installer: it uses exactly uv 0.12.18, the version this release was resolved and tested with, installed from its GitHub release asset and checked against a SHA-256 written in the script, into `~/.local/share/executive-stack/uv/` side by side with any uv you already have (yours is never touched or used unless it is that exact version; there is no curl-pipe-sh anywhere in this release). `run.sh` refuses to launch on any other uv, and refuses to launch at all if the locked environment cannot be verified (online, or offline against an intact environment).

**The easy way to configure it:** open this folder in Claude Code and say *"read backtalk.md and set me up."* The wizard picks your agent folder, your key, and your voice with you, then test-fires the whole loop.

**Already in a Claude Code session with your agent?** One sentence does the whole install: *"clone https://github.com/Executive-Stack-LLC/backtalk.git at tag es-2026.09.23-r1, then read backtalk/backtalk.md and set me up."* Your agent runs the installer and the wizard for you.

**The manual way:** copy `backtalk.json.example` to `backtalk.json` (your copy is untracked, so updates never touch it), then edit it. Point `agent_dir` at the folder whose CLAUDE.md is your agent, set `name` to your agent's name, pick a `ptt_key`. Then:

```
./run.sh
```

Hold the key. Talk. Let go.

## Windows

Windows has its own scripted installer, `install.ps1` (`install.sh` and `run.sh` are Mac and Linux). Open this folder in Claude Code and say *"read backtalk.md and set me up"*: the wizard runs `install.ps1` for you (the pinned uv 0.12.18 with a hash check, placed at `%LOCALAPPDATA%\ExecutiveStack\uv\uv.exe` side by side with any uv you already have; espeak-ng 1.52.0 from winget; `uv sync --frozen`; then the models), then launches with that uv: `& "$env:LOCALAPPDATA\ExecutiveStack\uv\uv.exe" run python -m backtalk.main` (the installer prints the exact path it used). The ElevenLabs key lives in the `ELEVENLABS_API_KEY` environment variable on Windows for now (Credential Manager support is planned). Hit something rough? The Windows notes in `TROUBLESHOOTING.md` carry the known quirks; for anything about this Executive Stack release, your Executive Stack contact, and for a bug in the software itself, the upstream project (https://github.com/jaredrhod/backtalk).

## The voice

Two engines, and the setup wizard offers you both instead of quietly defaulting.

**Built-in (Kokoro), the free one.** Local, offline, no accounts, no per-word costs, and honestly a bit computer-sounding. The default voice is `bm_lewis`, a British male with exactly the butler register. Around 60 voices ship free; set `voice` in `backtalk.json` (the first letter picks the language: `a` is American, `b` is British, and there are Spanish, French, Hindi, Italian, Japanese, Portuguese, and Chinese voices too).

**ElevenLabs, the natural one.** The human-sounding voice most people actually want, on your own API key. The free tier is enough to audition it; day-to-day talking runs on the paid starter plan. The wizard walks the whole thing with you: account, key into the keychain, then an audition of real voices through backtalk's own mouth until one fits. Under the hood it is: set `elevenlabs.enabled` and your `voice_id` in the config, and have `ffmpeg` installed. **The key never goes in a file.** On macOS, seed it into the Keychain once with `security add-generic-password -a "$USER" -s backtalk-elevenlabs -T /usr/bin/security -w` (it prompts for the secret) and backtalk reads it from there. Linux: `secret-tool store --label backtalk service backtalk-elevenlabs`. The `ELEVENLABS_API_KEY` environment variable works as a last resort, but an export in a shell profile is a plaintext key on disk; the keychain is the grown-up path. Kokoro stays wired in as the automatic fallback, so if the cloud fails the voice degrades instead of going mute, and `logs/backtalk.log` records why.

## Give it a face (optional)

backtalk writes tiny state files while it listens, thinks, and speaks, so anything can watch them and react in real time.

- **[ai-visualizer](https://github.com/Executive-Stack-LLC/ai-visualizer)** is the matching face: four full-screen visualizers, including the living circuit board. Point its `bus_dir` at this folder (or set `signals_dir` here to its folder) and it performs your actual conversation, idling, listening, thinking, and speaking along with the voice.

Mind ([ai-memory-vault](https://github.com/Executive-Stack-LLC/ai-memory-vault)), mouth (this), face (ai-visualizer).

## The fine print that matters

- **Usage:** every spoken turn is a real Claude Code turn, so a long voice session uses your plan the same way a long typing session does. The config pins the fast model tier on purpose; it's most of the speed, and it's the lighter draw.
- **Permissions: ask first, auto-approve by choice.** The default is `"ask"`: gated actions get a spoken permission check, answered by voice or by typing, and silence for about 75 seconds means no. `"bypassPermissions"` is auto-approve: the agent acts without asking, exactly like a terminal session with approvals off. Never hand-edit the file to switch; tell your agent to change it (takes effect the next time the voice line starts). "Start asking again" works by voice at any time; the spoken switch INTO auto-approve is disabled on Executive Stack installs unless `allow_voice_bypass` is set true in the config.
- **Two microphone modes, and the words mean what you think.** Push to talk (the default): the mic is closed except while you hold the key, so nothing records in the background, ever. **Hands-free listening**: always listening with voice detection; the setup asks which you want, "go hands free" / "push to talk mode" switches live and saves itself, and the talk key still works in hands-free as your interrupt. Tradeoffs in `TROUBLESHOOTING.md`. (Hands-free is about the MICROPHONE. Approvals are a separate setting called auto-approve; the two never share a name.)
- **The talk key needs a global key listener.** For the key to work when the voice line isn't your focused window, the process has to watch keyboard events system-wide. `backtalk/ptt.py` compares each event against the one key you configured and discards the rest. It stores nothing and writes nothing anywhere. About 130 lines, so you can read all of it in a couple of minutes. macOS asks for Input Monitoring permission before it will run, which is the OS telling you what the program can see.
- **Pin the microphone if you wear a headset.** By default it records from the system default input, which the OS hands to a headset the moment one connects, taking your voice down the narrowband call profile and degrading what you hear at the same time. Set `"mic_device"` in backtalk.json to the input you want, by name (`"MacBook Pro Microphone"`), and the mic stays put whatever connects for output. A name that matches nothing falls back to the default with a log line rather than going mute. (Credit where due: this grew out of a proposal by MacphersonDesigns.)
- Something misbehaving? `TROUBLESHOOTING.md` covers the classics, and `logs/backtalk.log` has the receipts. That log is a plain-text transcript of every spoken and typed line; it rotates at 5 MB and keeps three old copies (about 20 MB at most), and it never leaves the machine.

## Credits

Speech recognition by [faster-whisper](https://github.com/SYSTRAN/faster-whisper) (MIT) running [OpenAI Whisper](https://github.com/openai/whisper) models (MIT). Voice by [Kokoro](https://github.com/hexgrad/kokoro) (Apache 2.0) with [espeak-ng](https://github.com/espeak-ng/espeak-ng) (GPL-3.0, used as a system tool) for phonemization. Built on the [Claude Agent SDK](https://docs.claude.com/en/api/agent-sdk/overview).

## Updating

To update on macOS, double-click the `Update` icon setup left on your Desktop, or run `./update.sh` in this folder (it shows what is arriving and asks before applying). On Windows, or any time, say **"update backtalk to the current Executive Stack release and tell me what changed"** to your agent, and it does the same job. Updates only ever move to a release tag Executive Stack has published (the name in `ES_RELEASE` on the mirror's `es-release` branch), never to a moving branch. Your config, your keys, and your agent's identity live outside the tracked files, so updates never touch them. Installed through fullstack-agent? `./fullstack-agent/update.sh` (macOS) updates every piece at once and prints what changed.

## The rest of it

A voice is better with a face and a memory. The visualizer performs the conversation on screen while you talk, and the memory vault is what your agent actually speaks from, so it remembers you between sessions. [fullstack-agent](https://github.com/Executive-Stack-LLC/fullstack-agent) installs the memory, the voice, and the face, and wires them together for you.

## Support

Support: your Executive Stack contact.

## License and credit

Copyright (c) 2026 Jared Rhodenizer. This Executive Stack release is a modified version of the upstream project at https://github.com/jaredrhod/backtalk; the changes are listed in `NOTICE-EXECUTIVE-STACK.md`.

Licensed under the GNU Affero General Public License, version 3 or later (AGPL-3.0-or-later). **Use it in your business, commercially, for free.** Run it, change it, build your workflow on top of it, and charge for the work you do with it. The one rule is that it stays open: if you hand it to someone else, or run a modified version as a service other people use, your version ships under this same license with its source available. Credit the author when you build on it. Want it inside a closed-source commercial product? Email license@jaredrhod.com. Full terms are in the LICENSE file and at https://www.gnu.org/licenses/agpl-3.0.html
