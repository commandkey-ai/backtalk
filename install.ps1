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
# Added by Executive Stack, 2026-09-22 (see NOTICE-EXECUTIVE-STACK.md).
#
# backtalk installer for Windows: environment, engines, models. Run once
# from the backtalk folder in PowerShell:
#     powershell -ExecutionPolicy Bypass -File .\install.ps1
# Safe to re-run; every step skips what is already done.
#
# This is the scripted Windows lane. Upstream had the AI improvise the
# Windows install from prose; this file replaces that so every machine on
# an Executive Stack release installs the same way:
#   1. uv, PINNED to one version, downloaded from its GitHub release asset
#      and refused unless its SHA-256 matches the value written here.
#      (No `irm ... | iex`.)
#   2. espeak-ng from winget, PINNED to one version.
#   3. `uv sync --frozen` against the committed uv.lock (never re-resolved).
#   4. The speech models, prefetched at their pinned revisions.

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

$UvVersion = "0.12.18"
# SHA-256 of the uv release zips for this version. To move to a newer uv,
# change the version and both hashes in the same edit.
$UvSha256 = @{
    "x86_64-pc-windows-msvc"  = "cae6a3bc25239f83dffb467a4b180508d9da23986c04639ebfa44e43e6a84bff"
    "aarch64-pc-windows-msvc" = "17f27b1c64eacc757ae603579f116a014881e486c5e79ae81877980d4699e943"
}
$EspeakVersion = "1.52.0"

$release = ""
if (Test-Path "ES_RELEASE") { $release = (Get-Content "ES_RELEASE" -Raw).Trim() }
Write-Host "== backtalk install (Executive Stack release $release) =="

# --- uv (the Python environment manager), PINNED ---
$binDir = Join-Path $env:USERPROFILE ".local\bin"
$uvExe = Join-Path $binDir "uv.exe"
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if ($null -eq $uvCmd -and (Test-Path $uvExe)) { $uvCmd = Get-Command $uvExe }
if ($null -eq $uvCmd) {
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq "ARM64") { $target = "aarch64-pc-windows-msvc" }
    elseif ($arch -eq "AMD64") { $target = "x86_64-pc-windows-msvc" }
    else { throw "no pinned uv build for architecture '$arch'. Ask your Executive Stack contact." }
    $asset = "uv-$target.zip"
    $url = "https://github.com/astral-sh/uv/releases/download/$UvVersion/$asset"
    $tmp = Join-Path $env:TEMP ("backtalk-uv-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zip = Join-Path $tmp $asset
    Write-Host "-- downloading uv $UvVersion ($target) and checking its SHA-256"
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    $got = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
    $want = $UvSha256[$target]
    if ($got -ne $want) {
        Remove-Item -Recurse -Force $tmp
        throw "uv download HASH MISMATCH (expected $want, got $got). Refusing to install. Ask your Executive Stack contact."
    }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    New-Item -ItemType Directory -Force -Path $binDir | Out-Null
    Copy-Item -Path (Join-Path $tmp "uv.exe") -Destination $binDir -Force
    Copy-Item -Path (Join-Path $tmp "uvx.exe") -Destination $binDir -Force
    Remove-Item -Recurse -Force $tmp
    $env:Path = "$binDir;$env:Path"
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (($userPath -split ";") -notcontains $binDir) {
        [Environment]::SetEnvironmentVariable("Path", "$binDir;$userPath", "User")
    }
    $uvCmd = Get-Command $uvExe
    Write-Host "   uv installed to $binDir (new terminals see it on PATH)"
} else {
    $have = (& $uvCmd.Source --version) 2>$null
    Write-Host "-- uv: already present ($have; this release was built with $UvVersion)"
}
$uv = $uvCmd.Source

# --- espeak-ng (the one system library), PINNED via winget ---
$espeakDll = @(
    "C:\Program Files\eSpeak NG\libespeak-ng.dll",
    "C:\Program Files (x86)\eSpeak NG\libespeak-ng.dll"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($null -eq $espeakDll -and -not $env:PHONEMIZER_ESPEAK_LIBRARY) {
    if ($null -eq (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "espeak-ng is missing and winget is not available to install it. Ask your Executive Stack contact."
    }
    Write-Host "-- installing espeak-ng $EspeakVersion (the voice engine needs it)"
    & winget install --id eSpeak-NG.eSpeak-NG -e --version $EspeakVersion --source winget --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { throw "winget could not install espeak-ng $EspeakVersion (exit $LASTEXITCODE)." }
    $espeakDll = @(
        "C:\Program Files\eSpeak NG\libespeak-ng.dll",
        "C:\Program Files (x86)\eSpeak NG\libespeak-ng.dll"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($null -eq $espeakDll) { throw "espeak-ng installed but libespeak-ng.dll was not found under Program Files. Set PHONEMIZER_ESPEAK_LIBRARY to its path and re-run." }
} else {
    Write-Host "-- espeak-ng: already present"
}

# --- the Python environment, from the COMMITTED lockfile ---
# --frozen installs exactly what uv.lock says and never re-resolves
# against PyPI. --python 3.12 keeps every machine on the same interpreter
# line (uv fetches a managed build if none is present; uv verifies those
# downloads against hashes baked into the pinned uv binary).
Write-Host "-- creating the environment (first run downloads ~900MB of packages; it is not stuck)"
& $uv sync --frozen --python 3.12
if ($LASTEXITCODE -ne 0) { throw "uv sync --frozen failed (exit $LASTEXITCODE). The reason is in the output above." }

# --- prefetch the models so the first conversation doesn't wait ---
if ($args -notcontains "--no-models") {
    Write-Host "-- downloading the speech models at their pinned revisions (first run only, ~1GB total)"
    $py = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
    $warm = @'
import warnings; warnings.filterwarnings("ignore")
from backtalk.ears import warm as warm_ears
from backtalk.mouth import warm as warm_mouth
warm_ears()
warm_mouth()
print("-- models ready")
'@
    $warm | & $py -
    if ($LASTEXITCODE -ne 0) { throw "model prefetch failed (exit $LASTEXITCODE). The reason is in the output above." }
}

Write-Host ""
Write-Host "== backtalk installed =="
Write-Host ""
Write-Host "Next:"
Write-Host "  1. Point it at your agent: edit backtalk.json (agent_dir + name),"
Write-Host "     or open this folder in Claude Code and say:"
Write-Host "         read backtalk.md and set me up"
Write-Host "  2. uv run python -m backtalk.main   (hold the key, talk, let go)"
Write-Host ""
