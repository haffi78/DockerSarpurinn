#!/usr/bin/env bash
set -euo pipefail

mkdir -p /workspace/config /workspace/logs /workspace/state /workspace/cache /workspace/repo

LOG=/workspace/logs/bootstrap.log
touch "$LOG"

# Log to both docker logs and file
exec > >(tee -a "$LOG") 2>&1

echo "============================================================"
echo "[entrypoint] Start: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo "============================================================"
echo "[entrypoint] HOME=${HOME:-/workspace/config}"
echo "[entrypoint] Working dir: $(pwd)"
echo "[entrypoint] Listing /workspace:"
ls -lah /workspace || true

MARKER=/workspace/state/.initialized

# Make a working copy of repo in /workspace only if missing (optional but practical)
if [[ ! -d /workspace/repo/.git ]]; then
  echo "[entrypoint] Copying app repo into /workspace/repo (first time)..."
  git clone --depth 1 /opt/ruvsarpur /workspace/repo || cp -a /opt/ruvsarpur /workspace/repo
fi

# Ensure venv exists (persistent because /workspace is mounted)
if [[ ! -x /workspace/venv/bin/python ]]; then
  echo "[entrypoint] Creating Python venv..."
  python3 -m venv /workspace/venv
fi

echo "[entrypoint] Installing/updating Python dependencies into /workspace/venv..."
/workspace/venv/bin/pip install --upgrade pip setuptools wheel
if [[ -f /workspace/repo/requirements.txt ]]; then
  /workspace/venv/bin/pip install -r /workspace/repo/requirements.txt || true
fi
/workspace/venv/bin/pip install \
  colorama \
  termcolor \
  python-dateutil \
  requests \
  simplejson \
  fuzzywuzzy \
  python-levenshtein

echo "[entrypoint] Checking ffmpeg..."
which ffmpeg || true
ffmpeg -version | head -n 1 || true

echo "[entrypoint] ruvsarpur help test..."
/workspace/venv/bin/python /workspace/repo/src/ruvsarpur.py --help >/dev/null
echo "[entrypoint] ruvsarpur executable OK"

if [[ ! -f "$MARKER" ]]; then
  echo "[entrypoint] First-time initialization (marker not found)"
  echo "[entrypoint] Running one-time initial schedule refresh (--new)..."
  /workspace/venv/bin/python /workspace/repo/src/ruvsarpur.py --list --refresh --new 2>&1 | tr '\r' '\n' | sed '/^$/d' || \
    echo "[entrypoint] WARNING: Initial refresh failed (continuing)"

  date -u +'%Y-%m-%dT%H:%M:%SZ' > "$MARKER"
  echo "[entrypoint] Initialization marker created: $MARKER"
else
  echo "[entrypoint] Existing initialization marker found -> skipping first-time bootstrap"
fi

echo "[entrypoint] Ready"
echo "[entrypoint] Idle mode enabled (tail -f /dev/null)"
exec tail -f /dev/null
