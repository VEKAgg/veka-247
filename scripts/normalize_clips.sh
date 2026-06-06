#!/usr/bin/env bash
# normalize_clips.sh
# Pre-process raw clips to a consistent spec before adding to /srv/clips
# Fixes timebase mismatches that cause frame freezes at cut points
# Usage: ./normalize_clips.sh [input_dir] [output_dir]
#   Default input:  /srv/clips/raw
#   Default output: /srv/clips

set -euo pipefail

INPUT_DIR="${1:-/srv/clips/raw}"
OUTPUT_DIR="${2:-/srv/clips}"

if [ ! -d "$INPUT_DIR" ]; then
  echo "ERROR: Input directory not found: $INPUT_DIR"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

SUCCESS=0
FAILED=0

for f in "$INPUT_DIR"/*.{mp4,mkv,mov,avi,flv,ts}; do
  [ -f "$f" ] || continue
  filename=$(basename "$f" | sed 's/\.[^.]*$//')
  outfile="$OUTPUT_DIR/${filename}_norm.mp4"

  if [ -f "$outfile" ]; then
    echo "SKIP (exists): ${filename}_norm.mp4"
    continue
  fi

  echo "Normalizing: $filename ..."
  if ffmpeg -i "$f" \
    -vf "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=black,fps=30,format=yuv420p" \
    -c:v libx264 -preset fast -crf 18 -profile:v high \
    -c:a aac -b:a 128k -ar 44100 -ac 2 \
    -video_track_timescale 90000 \
    -movflags +faststart \
    "$outfile" -y 2>/dev/null; then
    echo "  Done: ${filename}_norm.mp4"
    SUCCESS=$((SUCCESS + 1))
  else
    echo "  FAILED: $filename"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "=== normalize_clips complete ==="
echo "  Success: $SUCCESS"
echo "  Failed:  $FAILED"
echo "  Output:  $OUTPUT_DIR"
