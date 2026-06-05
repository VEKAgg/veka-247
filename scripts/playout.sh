#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../config/stream.conf
source "$SCRIPT_DIR/../config/stream.conf"

FFMPEG_PID=""
LOG_MON_PID=""
FFMPEG_RC=0
FFMPEG_LOG="/run/247live/ffmpeg-stderr.log"

cleanup() {
  [ -n "$LOG_MON_PID" ] && kill "$LOG_MON_PID" 2>/dev/null || true
  [ -n "$FFMPEG_PID"  ] && kill "$FFMPEG_PID"  2>/dev/null || true
  [ -n "$FFMPEG_PID"  ] && wait "$FFMPEG_PID"  2>/dev/null || true
  rm -f "$FFMPEG_PID_FILE" "$FFMPEG_LOG"
  systemd-cat -t "$LOG_TAG" echo "Stream stopped."
  exit 0
}
trap cleanup SIGTERM SIGINT

# ── Credentials ───────────────────────────────────────────────────────────────
if [ -z "${CREDENTIALS_DIRECTORY:-}" ]; then
  echo "ERROR: CREDENTIALS_DIRECTORY not set. Run via systemd." >&2
  exit 1
fi
TW_KEY=$(cat "$CREDENTIALS_DIRECTORY/tw_key")

# ── Quality profile ───────────────────────────────────────────────────────────
case "${QUALITY_PROFILE:-720p30}" in
  "1080p60") W=1920; H=1080; FPS=60; VBR="6000k"; BUF="12000k"; GOP=120 ;;
  *)         W=1280; H=720;  FPS=30; VBR="2500k";  BUF="5000k";  GOP=60  ;;
esac

# ── Multi-platform output ─────────────────────────────────────────────────────
PLATFORMS=("Twitch")
TGTSTR="[f=flv]${TWITCH_RTMP}/${TW_KEY}"

# Uncomment to enable YouTube:
#if [ -s "${CREDENTIALS_DIRECTORY}/yt_key" ]; then
#  YT_KEY=$(cat "${CREDENTIALS_DIRECTORY}/yt_key")
#  TGTSTR+="|[f=flv]${YOUTUBE_RTMP}/${YT_KEY}"
#  PLATFORMS+=("YouTube")
#fi
# Uncomment to enable Kick:
#if [ -s "${CREDENTIALS_DIRECTORY}/kick_key" ]; then
#  KICK_KEY=$(cat "${CREDENTIALS_DIRECTORY}/kick_key")
#  TGTSTR+="|[f=flv]${KICK_RTMP}/${KICK_KEY}"
#  PLATFORMS+=("Kick")
#fi

# ── FFmpeg runner (overlay-aware) ─────────────────────────────────────────────
run_ffmpeg() {
  local playlist="$1"; shift
  local vf="scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2:color=black,fps=${FPS},format=yuv420p"
  local common_args=(
    -hide_banner -loglevel info -re
    -avoid_negative_ts make_zero
    -f concat -safe 0 -i "$playlist"
  )
  local encode_args=(
    -c:v libx264 -preset superfast -profile:v high
    -b:v "$VBR" -maxrate "$VBR" -bufsize "$BUF"
    -g "$GOP" -keyint_min "$GOP"
    -af "aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo"
    -c:a aac -b:a 128k
  )

  if [ -f "${OVERLAY_FILE:-}" ]; then
    ffmpeg "${common_args[@]}" \
      -stream_loop -1 -i "$OVERLAY_FILE" \
      -filter_complex "[0:v]${vf}[scaled];[scaled][1:v]overlay=0:0[out]" \
      -map "[out]" -map 0:a \
      "${encode_args[@]}" "$@"
  else
    ffmpeg "${common_args[@]}" \
      -vf "$vf" \
      "${encode_args[@]}" "$@"
  fi
}

systemd-cat -t "$LOG_TAG" echo "Starting stream → ${PLATFORMS[*]} (${QUALITY_PROFILE:-720p30})"

# ── Main loop ─────────────────────────────────────────────────────────────────
while true; do
  "$SCRIPT_DIR/generate_playlist.sh" || {
    systemd-cat -t "$LOG_TAG" -p warning echo "Playlist generation failed, retrying in 5s..."
    sleep 5
    continue
  }

  if [ "${#PLATFORMS[@]}" -eq 1 ]; then
    OUTPUT_FLAG=(-f flv "${TWITCH_RTMP}/${TW_KEY}")
  else
    OUTPUT_FLAG=(-f tee "$TGTSTR")
  fi

  FFMPEG_RC=0
  run_ffmpeg "$PLAYLIST" "${OUTPUT_FLAG[@]}" 2>"$FFMPEG_LOG" &
  FFMPEG_PID=$!
  echo "$FFMPEG_PID" > "$FFMPEG_PID_FILE"

  # Log clip changes from ffmpeg's stderr ("Opening '...' for reading")
  (tail -F "$FFMPEG_LOG" 2>/dev/null \
    | grep --line-buffered "Opening '/" \
    | while IFS= read -r line; do
        clip=$(sed "s|.*Opening '\\(.*\\)' for reading.*|\\1|" <<< "$line")
        systemd-cat -t "$LOG_TAG" echo "NOW PLAYING: $(basename "$clip")"
      done
  ) &
  LOG_MON_PID=$!

  wait "$FFMPEG_PID" || FFMPEG_RC=$?

  kill "$LOG_MON_PID" 2>/dev/null || true
  wait "$LOG_MON_PID" 2>/dev/null || true
  LOG_MON_PID=""
  FFMPEG_PID=""
  rm -f "$FFMPEG_PID_FILE" "$FFMPEG_LOG"

  systemd-cat -t "$LOG_TAG" -p warning echo "ffmpeg exited (code ${FFMPEG_RC}), reshuffling in ${RESTART_DELAY}s..."
  sleep "$RESTART_DELAY"
done
