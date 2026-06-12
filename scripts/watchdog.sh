#!/usr/bin/env bash
# watchdog.sh — health check for the veka-247 stack
# Runs every 2 minutes via ffplayout-watchdog.timer
# Restarts ffplayout if it has stopped; logs to systemd journal

set -euo pipefail

STREAM_KEY="247live"
RTMP_PORT=1935

check_ffplayout() {
  if ! systemctl is-active --quiet ffplayout; then
    echo "WATCHDOG: ffplayout is not active — restarting"
    systemctl restart ffplayout
    return 1
  fi
  return 0
}

check_rtmp_port() {
  # Verify Restreamer RTMP port is accepting connections
  if ! ss -tlnp | grep -q ":${RTMP_PORT}"; then
    echo "WATCHDOG: Restreamer RTMP port ${RTMP_PORT} not listening — check Docker container"
    docker ps --filter "name=restreamer" --format "{{.Names}} {{.Status}}" | \
      grep -q "Up" || docker compose -f /opt/247live/docker/docker-compose.yml up -d
    return 1
  fi
  return 0
}

check_clips() {
  CLIP_COUNT=$(find /srv/clips -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' \) 2>/dev/null | wc -l)
  if [ "$CLIP_COUNT" -eq 0 ]; then
    echo "WATCHDOG: No clips found in /srv/clips — stream has nothing to play"
    return 1
  fi
  return 0
}

ERRORS=0
check_ffplayout  || ERRORS=$((ERRORS + 1))
check_rtmp_port  || ERRORS=$((ERRORS + 1))
check_clips      || ERRORS=$((ERRORS + 1))

if [ "$ERRORS" -eq 0 ]; then
  echo "WATCHDOG: OK — ffplayout running, RTMP up, ${CLIP_COUNT:-?} clips available"
fi

exit 0
