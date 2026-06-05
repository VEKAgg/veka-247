#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../config/stream.conf
source "$SCRIPT_DIR/../config/stream.conf"

WATCHDOG_STATE="/run/247live/watchdog-last-pcpu"

# ── Helpers ───────────────────────────────────────────────────────────────────
format_uptime() {
  local ts="$1"
  if [ -z "$ts" ] || [ "$ts" = "n/a" ]; then echo "unknown"; return; fi
  local epoch
  epoch=$(date -d "$ts" +%s 2>/dev/null || echo "")
  if [ -z "$epoch" ]; then echo "$ts"; return; fi
  local diff=$(( $(date +%s) - epoch ))
  local d=$(( diff / 86400 ))
  local h=$(( (diff % 86400) / 3600 ))
  local m=$(( (diff % 3600) / 60 ))
  [ "$d" -gt 0 ] && echo "${d}d ${h}h ${m}m" && return
  [ "$h" -gt 0 ] && echo "${h}h ${m}m" && return
  echo "${m}m"
}

# ── Service info ──────────────────────────────────────────────────────────────
SVC_STATE=$(systemctl is-active playout.service 2>/dev/null || echo "inactive")
START_TS=$(systemctl show playout.service --property=ActiveEnterTimestamp --value 2>/dev/null || echo "")
UPTIME=$(format_uptime "$START_TS")

# ── FFmpeg PID ────────────────────────────────────────────────────────────────
if [ -f "$FFMPEG_PID_FILE" ]; then
  PID=$(cat "$FFMPEG_PID_FILE")
  if kill -0 "$PID" 2>/dev/null; then
    RSS=$(ps -o rss= -p "$PID" 2>/dev/null | tr -d ' ' || echo "?")
    RSS_MB=$(( ${RSS:-0} / 1024 ))
    PID_INFO="$PID (${RSS_MB} MB RSS)"
  else
    PID_INFO="$PID (dead)"
  fi
else
  PID_INFO="none"
fi

# ── Now playing ───────────────────────────────────────────────────────────────
NOW_PLAYING=$(journalctl -t "$LOG_TAG" --since "10 min ago" -q --no-pager 2>/dev/null \
  | grep "NOW PLAYING:" | tail -1 | sed 's/.*NOW PLAYING: //' || echo "unknown")

# ── Error count ───────────────────────────────────────────────────────────────
ERRORS=$(journalctl -t "$LOG_TAG" --since "1h ago" -q --no-pager 2>/dev/null \
  | grep -ci "error\|failed\|crash" 2>/dev/null || echo "0")

# ── NFS + clip count ──────────────────────────────────────────────────────────
if mountpoint -q "$CLIP_DIR" 2>/dev/null; then
  CLIP_COUNT=$(find "$CLIP_DIR" -maxdepth 1 -type f \
    \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' \
       -o -name '*.avi' -o -name '*.flv' -o -name '*.ts' \) \
    2>/dev/null | wc -l)
  NFS_INFO="OK ($CLIP_COUNT clips)"
else
  NFS_INFO="NOT MOUNTED"
fi

# ── Platforms ─────────────────────────────────────────────────────────────────
PLATFORMS="Twitch"
if [ -s "${CREDENTIALS_DIRECTORY:-/run/credentials/playout.service}/yt_key" ] 2>/dev/null; then
  PLATFORMS="$PLATFORMS, YouTube"
fi
if [ -s "${CREDENTIALS_DIRECTORY:-/run/credentials/playout.service}/kick_key" ] 2>/dev/null; then
  PLATFORMS="$PLATFORMS, Kick"
fi

# ── Watchdog last check ───────────────────────────────────────────────────────
if [ -f "$WATCHDOG_STATE" ]; then
  WD_AGE=$(( $(date +%s) - $(stat -c %Y "$WATCHDOG_STATE" 2>/dev/null || echo 0) ))
  WD_INFO="${WD_AGE}s ago — OK"
else
  WD_INFO="no check yet"
fi

# ── Output ────────────────────────────────────────────────────────────────────
printf '\n=== 247live Status — %s ===\n' "$(date '+%Y-%m-%d %H:%M:%S')"
printf 'Service:     %s\n' "$SVC_STATE (uptime: $UPTIME)"
printf 'FFmpeg PID:  %s\n' "$PID_INFO"
printf 'NFS:         %s\n' "$NFS_INFO"
printf 'Now playing: %s\n' "$NOW_PLAYING"
printf 'Errors (1h): %s\n' "$ERRORS"
printf 'Platforms:   %s\n' "$PLATFORMS"
printf 'Watchdog:    %s\n' "$WD_INFO"
printf '\n'
