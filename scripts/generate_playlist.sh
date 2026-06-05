#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../config/stream.conf
source "$SCRIPT_DIR/../config/stream.conf"

SUPPORTED_FORMATS=(-name '*.mp4' -o -name '*.mkv' -o -name '*.mov' -o -name '*.avi' -o -name '*.flv' -o -name '*.ts')

# ── NFS mount check ───────────────────────────────────────────────────────────
if ! mountpoint -q "$CLIP_DIR" 2>/dev/null; then
  if [ ! -d "$CLIP_DIR" ]; then
    systemd-cat -t "$LOG_TAG" -p err echo "CLIP_DIR does not exist: $CLIP_DIR"
    exit 1
  fi
  systemd-cat -t "$LOG_TAG" -p warning echo "WARNING: $CLIP_DIR is not a mount point — NFS may not be active"
fi

# ── Scan for candidates ───────────────────────────────────────────────────────
mapfile -t CANDIDATES < <(find "$CLIP_DIR" -maxdepth 1 -type f \( "${SUPPORTED_FORMATS[@]}" \))

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  systemd-cat -t "$LOG_TAG" -p err echo "No video files found in $CLIP_DIR"
  exit 1
fi

# ── Validate clips (optional) ─────────────────────────────────────────────────
TEMP_VALID=$(mktemp)
SKIPPED=0

for f in "${CANDIDATES[@]}"; do
  if [ "${VALIDATE_CLIPS:-true}" = "true" ]; then
    if timeout 5 ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$f" >/dev/null 2>&1; then
      echo "$f" >> "$TEMP_VALID"
    else
      SKIPPED=$((SKIPPED + 1))
      systemd-cat -t "$LOG_TAG" -p warning echo "SKIP (invalid): $(basename "$f")"
    fi
  else
    echo "$f" >> "$TEMP_VALID"
  fi
done

VALID_COUNT=$(wc -l < "$TEMP_VALID")

if [ "$VALID_COUNT" -lt "${PLAYLIST_MIN_CLIPS:-1}" ]; then
  systemd-cat -t "$LOG_TAG" -p err echo "Not enough valid clips: found $VALID_COUNT (need ${PLAYLIST_MIN_CLIPS:-1})"
  rm -f "$TEMP_VALID"
  exit 1
fi

[ "$SKIPPED" -gt 0 ] && systemd-cat -t "$LOG_TAG" -p warning echo "Skipped $SKIPPED invalid clips"

# ── Build playlist ────────────────────────────────────────────────────────────
TEMP_LIST=$(mktemp)
shuf "$TEMP_VALID" | awk '{printf "file '\''%s'\''\n", $0}' > "$TEMP_LIST"
rm -f "$TEMP_VALID"

REPEATS=$(( 2000 / VALID_COUNT + 1 ))
TEMP_PLAYLIST=$(mktemp)
for _ in $(seq 1 "$REPEATS"); do
  cat "$TEMP_LIST"
done >> "$TEMP_PLAYLIST"
rm -f "$TEMP_LIST"

# Atomic write — prevents ffmpeg reading a half-built playlist
mv "$TEMP_PLAYLIST" "$PLAYLIST"

TOTAL=$(( VALID_COUNT * REPEATS ))
systemd-cat -t "$LOG_TAG" echo "Playlist ready: $VALID_COUNT clips × $REPEATS passes = $TOTAL entries"
