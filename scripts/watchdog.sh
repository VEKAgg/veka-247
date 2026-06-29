#!/usr/bin/env bash
# watchdog.sh — health check for the veka-247 multi-channel stack
# Runs every 2 minutes via ffplayout-watchdog.timer

set -euo pipefail

COMPOSE_DIR="/opt/247live/docker"
CHANNELS="tttr igfv fh6 va"
RTMP_PORT=1935
ERRORS=0

# ── Check Docker is running ──────────────────────────────────────────────────
check_docker() {
  if ! docker info &>/dev/null; then
    echo "WATCHDOG: Docker is not running"
    return 1
  fi
  return 0
}

# ── Check all containers are up ──────────────────────────────────────────────
check_containers() {
  local all_up=true
  for svc in backend dashboard postgres mediamtx ffplayout-tttr ffplayout-igfv ffplayout-fh6 ffplayout-va restreamer; do
    if ! docker ps --filter "name=^${svc}$" --format "{{.Status}}" | grep -q "Up"; then
      echo "WATCHDOG: Container $svc is NOT running"
      all_up=false
    fi
  done
  if [ "$all_up" = false ]; then
    echo "WATCHDOG: Restarting stack..."
    cd "$COMPOSE_DIR" && docker compose up -d
    return 1
  fi
  return 0
}

# ── Check MediaMTX RTMP port ────────────────────────────────────────────────
check_mediamtx() {
  if ! ss -tlnp | grep -q ":${RTMP_PORT}"; then
    echo "WATCHDOG: MediaMTX RTMP port ${RTMP_PORT} not listening"
    return 1
  fi
  return 0
}

# ── Check PostgreSQL ─────────────────────────────────────────────────────────
check_postgres() {
  if ! docker exec veka-postgres pg_isready -U veka &>/dev/null; then
    echo "WATCHDOG: PostgreSQL is not responding"
    return 1
  fi
  return 0
}

# ── Check clips per channel ─────────────────────────────────────────────────
check_clips() {
  for ch in $CHANNELS; do
    count=$(find /srv/clips/"$ch" -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' -o -name '*.avi' -o -name '*.flv' -o -name '*.ts' \) 2>/dev/null | wc -l)
    if [ "$count" -eq 0 ]; then
      echo "WATCHDOG: No clips in /srv/clips/$ch"
    fi
  done
  return 0
}

# ── Check NFS mount ─────────────────────────────────────────────────────────
check_nfs() {
  if ! mountpoint -q /srv/clips; then
    echo "WATCHDOG: /srv/clips is not mounted (NFS may be down)"
    return 1
  fi
  return 0
}

# ── Run all checks ──────────────────────────────────────────────────────────
check_docker    || ERRORS=$((ERRORS + 1))
check_containers || ERRORS=$((ERRORS + 1))
check_mediamtx  || ERRORS=$((ERRORS + 1))
check_postgres  || ERRORS=$((ERRORS + 1))
check_nfs       || ERRORS=$((ERRORS + 1))
check_clips

if [ "$ERRORS" -eq 0 ]; then
  echo "WATCHDOG: OK — all services running"
fi

exit 0
