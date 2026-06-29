#!/usr/bin/env bash
# status.sh — check health of the veka-247 multi-channel stack
set -euo pipefail

echo "============================================"
echo "  veka-247 multi-channel status"
echo "============================================"
echo ""

# ── Docker containers ────────────────────────────────────────────────────────
echo "--- Docker containers ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not running or not accessible"
echo ""

# ── NFS mount /srv/clips ────────────────────────────────────────────────────
echo "--- NFS mount /srv/clips ---"
mountpoint -q /srv/clips && echo "/srv/clips: MOUNTED (TrueNAS 192.168.1.98)" || echo "/srv/clips: NOT MOUNTED"
echo ""

# ── Clips per channel ───────────────────────────────────────────────────────
echo "--- Clips available ---"
for ch in tttr igfv fh6 va; do
  count=$(find /srv/clips/"$ch" -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' -o -name '*.avi' -o -name '*.flv' -o -name '*.ts' \) 2>/dev/null | wc -l)
  printf "  %-8s %s clips\n" "$ch" "$count"
done
echo ""

# ── Endpoints ────────────────────────────────────────────────────────────────
echo "--- Endpoints ---"
VM_IP=$(hostname -I | awk '{print $1}')
echo "  Dashboard       -> http://${VM_IP}:3000"
echo "  Backend API     -> http://${VM_IP}:8000"
echo "  ffplayout TTTR  -> http://${VM_IP}:8787"
echo "  ffplayout IGFV  -> http://${VM_IP}:8788"
echo "  ffplayout FH6   -> http://${VM_IP}:8789"
echo "  ffplayout VA    -> http://${VM_IP}:8790"
echo "  Restreamer      -> http://${VM_IP}:8080"
echo "  MediaMTX HLS    -> http://${VM_IP}:8888"
echo "  MediaMTX API    -> http://${VM_IP}:9997"
echo "  IRL Ingest      -> rtmp://${VM_IP}:1935/live/irl"
echo ""

# ── PostgreSQL ───────────────────────────────────────────────────────────────
echo "--- PostgreSQL ---"
docker exec veka-postgres pg_isready -U veka 2>/dev/null && echo "  PostgreSQL: RUNNING" || echo "  PostgreSQL: NOT RUNNING"
echo ""

# ── Twitch Mumbai ───────────────────────────────────────────────────────────
echo "--- Platform Config ---"
echo "  Twitch Mumbai RTMP: rtmp://aps30.contribute.live-video.net/app/{KEY}"
echo "  YouTube RTMP:       rtmp://a.rtmp.youtube.com/live2/{KEY}"
echo "  Kick RTMP:          rtps://{account-id}.global-contribute.live-video.net:443/app/{KEY}"
echo ""
echo "============================================"
