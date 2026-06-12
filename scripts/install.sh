#!/usr/bin/env bash
# install.sh — veka-247 one-command setup
# Usage: sudo bash scripts/install.sh
#
# Before running, create a .env file in the repo root:
#   cp .env.example .env && nano .env
# Fill in your TWITCH_KEY. That's the only required step.

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

# ── Load .env ────────────────────────────────────────────────────────────────
step "Loading .env"
ENV_FILE="$REPO_DIR/.env"
[ -f "$ENV_FILE" ] || die ".env not found. Run: cp .env.example .env && nano .env"
set -a; source "$ENV_FILE"; set +a

[ -n "${TWITCH_KEY:-}" ] || die "TWITCH_KEY is not set in .env"
ok "Stream key loaded"

# ── Docker ───────────────────────────────────────────────────────────────────
step "Checking Docker"
command -v docker &>/dev/null || die "Docker not found. Install Docker first: https://docs.docker.com/engine/install/ubuntu/"
docker compose version &>/dev/null || die "Docker Compose plugin not found."
systemctl enable --now docker
ok "Docker is running"

# ── ffplayout ─────────────────────────────────────────────────────────────────
step "Installing ffplayout"
if command -v ffplayout &>/dev/null; then
  CURRENT_VER=$(ffplayout --version 2>/dev/null | head -1 || echo "unknown")
  warn "ffplayout already installed (${CURRENT_VER})"
else
  DEB_FILE="ffplayout_v${FFPLAYOUT_VERSION}-1_amd64.deb"
  DEB_URL="https://github.com/ffplayout/ffplayout/releases/download/v${FFPLAYOUT_VERSION}/${DEB_FILE}"
  warn "Downloading ffplayout v${FFPLAYOUT_VERSION}..."
  wget -q "$DEB_URL" -O "/tmp/${DEB_FILE}" || die "Failed to download ffplayout"
  apt-get install -y "/tmp/${DEB_FILE}" || die "Failed to install ffplayout"
  rm -f "/tmp/${DEB_FILE}"
  ok "ffplayout v${FFPLAYOUT_VERSION} installed"
fi

# ── Directories ───────────────────────────────────────────────────────────────
step "Creating directories"
REAL_USER="${SUDO_USER:-$(logname)}"
mkdir -p \
  "$INSTALL_DIR/playlists" \
  "$INSTALL_DIR/logs/ffplayout" \
  "$INSTALL_DIR/restreamer/config" \
  "$INSTALL_DIR/restreamer/data"
mkdir -p /srv/clips
chown -R "${REAL_USER}:${REAL_USER}" "$INSTALL_DIR"
chown "${REAL_USER}:${REAL_USER}" /srv/clips
chmod 755 /srv/clips
ok "Directories ready (owned by ${REAL_USER})"

# ── NFS ───────────────────────────────────────────────────────────────────────
step "Checking NFS mount /srv/clips"
if mountpoint -q /srv/clips; then
  ok "/srv/clips is mounted"
else
  warn "/srv/clips is not mounted. Add this to /etc/fstab and run: mount /srv/clips"
  warn "  ${TRUENAS_IP:-192.168.1.98}:/srv/clips /srv/clips nfs nofail,_netdev 0 0"
fi

# ── ffplayout config ──────────────────────────────────────────────────────────
step "Configuring ffplayout"
if [ ! -f /etc/ffplayout/ffplayout.db ]; then
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

# Inject stream key into config and install it
mkdir -p /etc/ffplayout
sed "s|YOUR_TWITCH_STREAM_KEY|${TWITCH_KEY}|g" \
  "$REPO_DIR/config/ffplayout.yml" > /etc/ffplayout/ffplayout.yml
chown ffpu:nogroup /etc/ffplayout/ffplayout.yml
ok "Config installed (stream key injected)"

# ── Start ffplayout ───────────────────────────────────────────────────────────
step "Starting ffplayout service"
systemctl enable --now ffplayout
systemctl restart ffplayout
ok "ffplayout service started"

# ── Restreamer (optional, for multi-platform) ─────────────────────────────────
step "Starting Restreamer (optional multi-platform relay)"
cd "$REPO_DIR/docker"
# Only pull/start if not already running — avoids resetting the Restreamer config
if ! docker ps --format '{{.Names}}' | grep -q '^restreamer$'; then
  docker compose pull
  docker compose up -d
  ok "Restreamer started"
else
  warn "Restreamer already running — skipping restart to preserve config"
fi

# ── Watchdog ──────────────────────────────────────────────────────────────────
step "Installing watchdog"
cp "$REPO_DIR/scripts/watchdog.sh" /usr/local/bin/ffplayout-watchdog
chmod +x /usr/local/bin/ffplayout-watchdog
cp "$REPO_DIR/systemd/ffplayout-watchdog.service" /etc/systemd/system/
cp "$REPO_DIR/systemd/ffplayout-watchdog.timer"   /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now ffplayout-watchdog.timer
ok "Watchdog enabled (checks every 2 min, auto-restarts if needed)"

# ── Done ──────────────────────────────────────────────────────────────────────
VM_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================================"
echo "  veka-247 is live"
echo "============================================================"
echo "  Streaming to  -> Twitch (key from .env)"
echo "  ffplayout UI  -> http://${VM_IP}:8787  (admin / admin)"
echo "  Restreamer UI -> http://${VM_IP}:8080  (optional)"
echo ""
echo "  Clips folder  -> /srv/clips"
echo "  Add clips     -> scp clip.mp4 ${REAL_USER}@${VM_IP}:/srv/clips/"
echo "  Status        -> bash scripts/status.sh"
echo "  Logs          -> journalctl -u ffplayout -f"
echo "============================================================"
