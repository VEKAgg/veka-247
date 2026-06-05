#!/usr/bin/env bash
set -euo pipefail

CLIP_DIR="/srv/clips"
PLAYLIST="/tmp/playlist.txt"
SUPPORTED_FORMATS=(-name '*.mp4' -o -name '*.mkv' -o -name '*.mov' -o -name '*.avi' -o -name '*.flv' -o -name '*.ts')

if [ ! -d "$CLIP_DIR" ]; then
  echo "ERROR: $CLIP_DIR does not exist. Is the NFS mount active?" >&2
  exit 1
fi

FILE_COUNT=$(find "$CLIP_DIR" -maxdepth 1 -type f \( "${SUPPORTED_FORMATS[@]}" \) | wc -l)

if [ "$FILE_COUNT" -eq 0 ]; then
  echo "ERROR: No video files found in $CLIP_DIR" >&2
  exit 1
fi

echo "Found $FILE_COUNT video clips in $CLIP_DIR"

find "$CLIP_DIR" -maxdepth 1 -type f \( "${SUPPORTED_FORMATS[@]}" \) \
  | shuf \
  | awk '{printf "file '\''%s'\''\n", $0}' \
  > "$PLAYLIST"

echo "Playlist generated: $PLAYLIST ($FILE_COUNT files)"
