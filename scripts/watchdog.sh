#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../config/stream.conf
source "$SCRIPT_DIR/../config/stream.conf"

WATCHDOG_STATE="/run/247live/watchdog-last-pcpu"

log() { systemd-cat -t "247live-watchdog" echo "$1"; }
log_warn() { systemd-cat -t "247live-watchdog" -p warning echo "$1"; }

# Don't fight intentional stops
if ! systemctl is-active --quiet playout.service; then
  exit 0
fi

# ── PID check ─────────────────────────────────────────────────────────────────
if [ ! -f "$FFMPEG_PID_FILE" ]; then
  log_warn "PID file missing — ffmpeg may have crashed. Restarting playout..."
  systemctl restart playout.service
  exit 0
fi

PID=$(cat "$FFMPEG_PID_FILE")

if ! kill -0 "$PID" 2>/dev/null; then
  log_warn "ffmpeg PID $PID is dead. Restarting playout..."
  rm -f "$FFMPEG_PID_FILE"
  systemctl restart playout.service
  exit 0
fi

# ── NFS check ─────────────────────────────────────────────────────────────────
if ! mountpoint -q "$CLIP_DIR" 2>/dev/null; then
  log_warn "NFS mount gone ($CLIP_DIR). Restarting playout to recover..."
  systemctl restart playout.service
  exit 0
fi

# ── CPU stall detection ───────────────────────────────────────────────────────
# If ffmpeg shows near-zero CPU on two consecutive watchdog runs it's likely
# hung on a stale NFS handle or a corrupt file. Restart.
CURRENT_CPU=$(ps -o pcpu= -p "$PID" 2>/dev/null | tr -d ' ' || echo "0.0")
ELAPSED=$(ps -o etimes= -p "$PID" 2>/dev/null | tr -d ' ' || echo "0")

if [ -f "$WATCHDOG_STATE" ]; then
  LAST_CPU=$(cat "$WATCHDOG_STATE")
  # Both runs near-zero AND process has been alive > 60s = stall
  if awk "BEGIN{exit !($CURRENT_CPU < 0.5 && $LAST_CPU < 0.5 && $ELAPSED > 60)}"; then
    log_warn "ffmpeg CPU stall detected (now: ${CURRENT_CPU}%, last: ${LAST_CPU}%, uptime: ${ELAPSED}s). Restarting..."
    rm -f "$WATCHDOG_STATE"
    systemctl restart playout.service
    exit 0
  fi
fi

echo "$CURRENT_CPU" > "$WATCHDOG_STATE"
log "OK — PID $PID, CPU ${CURRENT_CPU}%, NFS OK"
