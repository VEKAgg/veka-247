#!/usr/bin/env bash
# install.sh — veka-247 full stack deployment
# Usage: sudo bash scripts/install.sh

set -euo pipefail

INSTALL_DIR="/opt/247live"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { printf "${GREEN}  [OK]${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}  [WARN]${NC} %s\n" "$1"; }
die()  { printf "${RED}  [ERR]${NC} %s\n" "$1"; exit 1; }
step() { printf "\n${YELLOW}==> ${NC}%s\n" "$1"; }

[ "$(id -u)" -eq 0 ] || die "Run as root: sudo bash scripts/install.sh"

step "Checking Docker"
command -v docker &>/dev/null || die "Docker not found. Install Docker first."
docker compose version &>/dev/null || die "Docker Compose not found."
sudo systemctl enable --now docker
ok "Docker is running"

step "Creating directories"
mkdir -p \
  "$INSTALL_DIR/playlists/tttr" \
  "$INSTALL_DIR/playlists/igfv" \
  "$INSTALL_DIR/playlists/fh6" \
  "$INSTALL_DIR/playlists/va" \
  "$INSTALL_DIR/logs/ffplayout-tttr" \
  "$INSTALL_DIR/logs/ffplayout-igfv" \
  "$INSTALL_DIR/logs/ffplayout-fh6" \
  "$INSTALL_DIR/logs/ffplayout-va" \
  "$INSTALL_DIR/restreamer/config" \
  "$INSTALL_DIR/restreamer/data" \
  "$INSTALL_DIR/postgres/data" \
  /srv/clips/tttr \
  /srv/clips/igfv \
  /srv/clips/fh6 \
  /srv/clips/va \
  /srv/overlays
ok "Directories ready"

step "Checking NFS mount /srv/clips"
if mountpoint -q /srv/clips; then
  ok "/srv/clips is mounted"
else
  warn "/srv/clips is not mounted. Add to /etc/fstab:"
  warn "  192.168.1.98:/mnt/tank/247Live /srv/clips nfs nofail,_netdev 0 0"
fi

step "Pulling Docker images"
cd "$REPO_DIR/docker"
docker compose pull
ok "Images pulled"

step "Building custom images"
docker compose build
ok "Custom images built"

step "Starting stack"
docker compose up -d
ok "Stack started"

step "Waiting for PostgreSQL"
sleep 5
docker exec veka-postgres pg_isready -U veka && ok "PostgreSQL ready" || warn "PostgreSQL may still be starting"

VM_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================"
echo "  veka-247 stack is running"
echo "============================================"
echo ""
echo "  Dashboard       -> http://${VM_IP}:3000"
echo "  Backend API     -> http://${VM_IP}:8000"
echo "  ffplayout TTTR  -> http://${VM_IP}:8787"
echo "  ffplayout IGFV  -> http://${VM_IP}:8788"
echo "  ffplayout FH6   -> http://${VM_IP}:8789"
echo "  ffplayout VA    -> http://${VM_IP}:8790"
echo "  Restreamer      -> http://${VM_IP}:8080"
echo "  MediaMTX HLS    -> http://${VM_IP}:8888"
echo "  IRL Ingest      -> rtmp://${VM_IP}:1935/live/irl"
echo ""
echo "  Next steps:"
echo "  1. Open Restreamer UI (:8080) and add Twitch/YouTube/Kick outputs"
echo "  2. Drop clips into /srv/clips/{tttr,igfv,fh6,va}"
echo "  3. Use Dashboard (:3000) to manage channels and platforms"
echo "  4. Run scripts/status.sh to check health"
echo "============================================"
