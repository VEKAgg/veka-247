#!/usr/bin/env bash
# status.sh (rta branch) - check health of the veka-247 Docker stack
set -euo pipefail

echo "=== veka-247 rta status ==="
echo ""
echo "--- Docker containers ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not running or not accessible"
echo ""
echo "--- NFS mount /srv/clips ---"
mountpoint -q /srv/clips && echo "/srv/clips: MOUNTED (TrueNAS 192.168.1.98)" || echo "/srv/clips: NOT MOUNTED"
echo ""
echo "--- Clips available ---"
find /srv/clips -maxdepth 1 -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' \) 2>/dev/null | wc -l | xargs echo "Total clip files:"
echo ""
echo "--- Web UIs ---"
VM_IP=$(hostname -I | awk '{print $1}')
echo "  ffplayout  -> http://${VM_IP}:8787"
echo "  Restreamer -> http://${VM_IP}:8080"
