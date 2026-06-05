#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIP_DIR="/srv/clips"
PLAYLIST="/tmp/playlist.txt"

# ─── Load Credentials ────────────────────────────────────
if [ -z "${CREDENTIALS_DIRECTORY:-}" ]; then
  echo "ERROR: CREDENTIALS_DIRECTORY not set. Run via systemd." >&2
  exit 1
fi

TW_KEY=$(cat "$CREDENTIALS_DIRECTORY/tw_key")
#YT_KEY=$(cat "$CREDENTIALS_DIRECTORY/yt_key")
#KICK_KEY=$(cat "$CREDENTIALS_DIRECTORY/kick_key")
# ──────────────────────────────────────────────────────────

# ─── Generate Playlist ───────────────────────────────────
"$SCRIPT_DIR/generate_playlist.sh"
# ──────────────────────────────────────────────────────────

echo "Starting 24/7 playout stream..."

ffmpeg -re -stream_loop -1 \
  -f concat -safe 0 -i "$PLAYLIST" \
  -c:v libx264 -preset superfast -profile:v high \
  -b:v 4000k -maxrate 4000k -bufsize 8000k \
  -g 60 -keyint_min 60 -r 30 -pix_fmt yuv420p \
  -c:a aac -b:a 128k -ar 44100 \
  -f tee -map 0:v -map 0:a \
  "[f=flv]rtmp://live.twitch.tv/app/${TW_KEY}"

#"[f=flv]${YT_KEY}|[f=flv]${TW_KEY}|[f=flv]${KICK_KEY}"
