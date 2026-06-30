#!/usr/bin/env bash
# install.sh — veka-247 one-command setup
# Usage: sudo bash scripts/install.sh
#
# After running this, open http://<VM_IP>:8787 and configure the channel:
#   Settings → Playout → Output → mode: stream
#   Output Parameter: -c:v libx264 ... rtmp://live.twitch.tv/app/YOUR_KEY

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

# ── Docker ───────────────────────────────────────────────────────────────────
step "Checking Docker"
command -v docker &>/dev/null || die "Docker not found. Install it first: https://docs.docker.com/engine/install/ubuntu/"
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
chown -R ffpu:nogroup "$INSTALL_DIR/logs"
chown "${REAL_USER}:${REAL_USER}" /srv/clips
chmod 755 /srv/clips
ok "Directories ready (owned by ${REAL_USER})"

# ── NFS ───────────────────────────────────────────────────────────────────────
step "Checking NFS mount /srv/clips"
if mountpoint -q /srv/clips; then
  ok "/srv/clips is mounted"
else
  warn "/srv/clips is not mounted. Add to /etc/fstab:"
  warn "  192.168.1.98:/srv/clips /srv/clips nfs nofail,_netdev 0 0"
fi

# ── ffplayout init ────────────────────────────────────────────────────────────
step "Initialising ffplayout"
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
  ok "ffplayout initialised"
else
  warn "ffplayout DB already exists — skipping init (existing config preserved)"
fi

# ── Start ffplayout ───────────────────────────────────────────────────────────
step "Starting ffplayout"
systemctl enable --now ffplayout
systemctl restart ffplayout
ok "ffplayout running on http://$(hostname -I | awk '{print $1}'):8787"

# ── Restreamer ────────────────────────────────────────────────────────────────
step "Starting Restreamer"
cd "$REPO_DIR/docker"
if ! docker ps --format '{{.Names}}' | grep -q '^restreamer$'; then
  docker compose pull
  docker compose up -d
  ok "Restreamer started on http://$(hostname -I | awk '{print $1}'):8080"
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
ok "Watchdog enabled (checks every 2 min)"

# ── Done ──────────────────────────────────────────────────────────────────────
VM_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================================"
echo "  veka-247 installed"
echo "============================================================"
echo "  ffplayout UI  -> http://${VM_IP}:8787  (admin / admin)"
echo "  Restreamer UI -> http://${VM_IP}:8080"
echo ""
echo "  STEP 1 — Set up Restreamer (do this first):"
echo "    Open http://${VM_IP}:8080"
echo "    → complete first-time admin setup"
echo "    → + Add stream → create a new channel"
echo "    → Ingest tab: note your stream key (e.g. 'veka-live')"
echo "    → Outputs tab: Add output → Twitch → paste your Twitch key"
echo "    → Save → Start channel"
echo ""
echo "  STEP 2 — Point ffplayout at Restreamer:"
echo "    Open http://${VM_IP}:8787 → Settings → Playout → Output"
echo "    Mode: stream"
echo "    Output Parameter:"
echo "      -c:v libx264 -preset superfast -profile:v high"
echo "      -b:v 2500k -maxrate 2500k -bufsize 5000k -g 60 -r 30"
echo "      -pix_fmt yuv420p -c:a aac -b:a 128k -ar 44100 -f flv"
echo "      rtmp://127.0.0.1:1935/live/YOUR_RESTREAMER_KEY"
echo "    Save → Player → Start"
echo ""
echo "  To add YouTube / Kick later: add outputs in Restreamer UI only"
echo "  Clips:  scp clip.mp4 ${REAL_USER}@${VM_IP}:/srv/clips/"
echo "  Status: bash scripts/status.sh"
echo "============================================================"
