#!/usr/bin/env bash
# install.sh (rta branch)
# Sets up the veka-247 rta stack: Docker-based ffplayout + Restreamer
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
  "$INSTALL_DIR/playlists" \
  "$INSTALL_DIR/logs/ffplayout" \
  "$INSTALL_DIR/restreamer/config" \
  "$INSTALL_DIR/restreamer/data"
mkdir -p /srv/clips
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

step "Starting stack"
docker compose up -d
ok "Stack started"

VM_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================"
echo "  veka-247 rta stack is running"
echo "============================================"
echo "  ffplayout UI  -> http://${VM_IP}:8787"
echo "  Restreamer UI -> http://${VM_IP}:8080"
echo ""
echo "  Next steps:"
echo "  1. Open Restreamer UI and add Twitch/YouTube/Kick outputs"
echo "  2. Drop clips into /srv/clips"
echo "  3. ffplayout picks them up automatically"
echo "  4. Run scripts/status.sh to check health"
echo "============================================"
