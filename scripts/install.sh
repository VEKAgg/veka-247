#!/usr/bin/env bash
# install.sh (rta branch)
# Sets up the veka-247 rta stack: native ffplayout + Docker Restreamer
# Usage: sudo bash scripts/install.sh

set -euo pipefail

INSTALL_DIR="/opt/247live"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
FFPLAYOUT_VERSION="1.1.0"

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

step "Installing ffplayout"
if command -v ffplayout &>/dev/null; then
  CURRENT_VER=$(ffplayout --version 2>/dev/null || echo "unknown")
  warn "ffplayout already installed (${CURRENT_VER})"
else
  cd /tmp
  DEB_FILE="ffplayout_v${FFPLAYOUT_VERSION}-1_amd64.deb"
  DEB_URL="https://github.com/ffplayout/ffplayout/releases/download/v${FFPLAYOUT_VERSION}/${DEB_FILE}"
  warn "Downloading ffplayout v${FFPLAYOUT_VERSION}..."
  wget -q "$DEB_URL" -O "/tmp/${DEB_FILE}" || die "Failed to download ffplayout"
  apt-get install -y "/tmp/${DEB_FILE}" || die "Failed to install ffplayout"
  rm -f "/tmp/${DEB_FILE}"
  ok "ffplayout v${FFPLAYOUT_VERSION} installed"
fi

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
  warn "  192.168.1.98:/srv/clips /srv/clips nfs nofail,_netdev 0 0"
fi

step "Configuring ffplayout"
# Copy config if not already present
if [ ! -f /etc/ffplayout/ffplayout.yml ] || [ ! -f /etc/ffplayout/ffplayout.db ]; then
  # First-time initialization
  sudo -u ffpu ffplayout -i \
    -u admin \
    -p admin \
    -m admin@veka.local \
    --storage "/srv/clips" \
    --playlists "$INSTALL_DIR/playlists" \
    --public "/usr/share/ffplayout/public" \
    --logs "$INSTALL_DIR/logs/ffplayout" \
    --smtp-server "" \
    --smtp-user "" \
    --smtp-password "" \
    --smtp-port 465 \
    --smtp-starttls false \
    || warn "ffplayout init may have partially failed (existing db?)"
  ok "ffplayout initialized"
fi

# Ensure our custom config is in place
mkdir -p /etc/ffplayout
cp "$REPO_DIR/config/ffplayout.yml" /etc/ffplayout/ffplayout.yml
chown ffpu:ffpu /etc/ffplayout/ffplayout.yml
ok "Config installed"

step "Starting ffplayout service"
systemctl enable --now ffplayout
ok "ffplayout service started"

step "Pulling Restreamer Docker image"
cd "$REPO_DIR/docker"
docker compose pull
ok "Image pulled"

step "Starting Restreamer"
docker compose up -d
ok "Restreamer started"

step "Installing watchdog"
cp "$REPO_DIR/scripts/watchdog.sh" /usr/local/bin/ffplayout-watchdog
chmod +x /usr/local/bin/ffplayout-watchdog
cp "$REPO_DIR/systemd/ffplayout-watchdog.service" /etc/systemd/system/
cp "$REPO_DIR/systemd/ffplayout-watchdog.timer"   /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now ffplayout-watchdog.timer
ok "Watchdog timer enabled (checks every 2 min)"

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
