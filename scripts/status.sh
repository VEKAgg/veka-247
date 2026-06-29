#!/usr/bin/env bash
# status.sh (rta branch) - check health of the veka-247 stack
set -euo pipefail

echo "=== veka-247 multi-channel status ==="
echo ""
echo "--- ffplayout service ---"
systemctl is-active ffplayout 2>/dev/null && echo "ffplayout: RUNNING" || echo "ffplayout: NOT RUNNING"
echo ""
echo "--- Docker containers ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not running or not accessible"
echo ""
echo "--- NFS mount /srv/clips ---"
mountpoint -q /srv/clips && echo "/srv/clips: MOUNTED (TrueNAS 192.168.1.98)" || echo "/srv/clips: NOT MOUNTED"
echo ""
echo "--- Clips available ---"
echo "TTTR:" $(find /srv/clips/tttr -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' \) 2>/dev/null | wc -l)
echo "IGFV:" $(find /srv/clips/igfv -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' \) 2>/dev/null | wc -l)
echo "FH6:" $(find /srv/clips/fh6 -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' \) 2>/dev/null | wc -l)
echo "IRL Fallback:" $(find /srv/clips/irl-fallback -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' \) 2>/dev/null | wc -l)
echo ""
echo "--- Endpoints ---"
VM_IP=$(hostname -I | awk '{print $1}')
echo "  ffplayout TTTR -> http://${VM_IP}:8787"
echo "  ffplayout IGFV -> http://${VM_IP}:8788"
echo "  ffplayout FH6  -> http://${VM_IP}:8789"
echo "  OBS Studio     -> http://${VM_IP}:3000"
echo "  Restreamer     -> http://${VM_IP}:8080"
echo "  IRL Ingest     -> rtmp://${VM_IP}:1935/live/irl"
