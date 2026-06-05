#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYLIST="/tmp/playlist.txt"
FFMPEG_PID=""

# ─── Load Credentials ────────────────────────────────────
if [ -z "${CREDENTIALS_DIRECTORY:-}" ]; then
  echo "ERROR: CREDENTIALS_DIRECTORY not set. Run via systemd." >&2
  exit 1
fi
TW_KEY=$(cat "$CREDENTIALS_DIRECTORY/tw_key")
#YT_KEY=$(cat "$CREDENTIALS_DIRECTORY/yt_key")
#KICK_KEY=$(cat "$CREDENTIALS_DIRECTORY/kick_key")
# ──────────────────────────────────────────────────────────

# Clean shutdown when systemd sends SIGTERM (e.g. from the refresh timer)
trap 'echo "Caught signal, stopping ffmpeg..." >&2; kill "$FFMPEG_PID" 2>/dev/null; wait "$FFMPEG_PID" 2>/dev/null; exit 0' SIGTERM SIGINT

echo "Starting 24/7 playout stream..."

while true; do
  # Regenerate a fresh shuffled playlist every loop pass
  "$SCRIPT_DIR/generate_playlist.sh" || {
    echo "Playlist generation failed, retrying in 5s..." >&2
    sleep 5
    continue
  }

  FFMPEG_RC=0
  ffmpeg -hide_banner -re \
    -f concat -safe 0 -i "$PLAYLIST" \
    -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=black,fps=30,format=yuv420p" \
    -c:v libx264 -preset superfast -profile:v high \
    -b:v 2500k -maxrate 2500k -bufsize 5000k \
    -g 60 -keyint_min 60 \
    -af "aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo" \
    -c:a aac -b:a 128k \
    -f flv "rtmp://live.twitch.tv/app/${TW_KEY}" &
  # Multi-platform (replace the -f flv line above with this):
  # -f tee "[f=flv]rtmp://live.twitch.tv/app/${TW_KEY}|[f=flv]rtmp://a.rtmp.youtube.com/live2/${YT_KEY}|[f=flv]rtmp://fa723fc1b171.global-contribute.live-video.net/app/${KICK_KEY}" &

  FFMPEG_PID=$!
  wait "$FFMPEG_PID" || FFMPEG_RC=$?

  echo "ffmpeg exited (code $FFMPEG_RC), reshuffling and restarting in 3s..." >&2
  sleep 3
done
