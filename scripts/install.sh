#!/usr/bin/env bash
set -euo pipefail

# Must be run as root from the repo root, e.g.:
#   sudo bash scripts/install.sh

INSTALL_DIR="/opt/247live"
CREDSTORE="/etc/credstore"
SYSTEMD_DIR="/etc/systemd/system"
TMPFILES="/etc/tmpfiles.d/247live.conf"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { printf "${GREEN}  ✓${NC} %s\n" "$1"; }
warn() { printf "${YELLOW}  !${NC} %s\n" "$1"; }
die()  { printf "${RED}  ✗${NC} %s\n" "$1"; exit 1; }
step() { printf "\n${YELLOW}→${NC} %s\n" "$1"; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
[ "$(id -u)" -eq 0 ] || die "Run as root: sudo bash scripts/install.sh"

if [ ! -d "$INSTALL_DIR" ]; then
  die "Install dir not found: $INSTALL_DIR — copy the repo there first:
  sudo cp -r . $INSTALL_DIR"
fi

id vortek >/dev/null 2>&1 || die "User 'vortek' does not exist"

# ── Script permissions ────────────────────────────────────────────────────────
step "Setting script permissions"
chmod +x "$INSTALL_DIR"/scripts/*.sh
ok "All scripts marked executable"

# ── Credstore setup ───────────────────────────────────────────────────────────
step "Preparing credential store"
install -d -m 700 -o root -g root "$CREDSTORE"

if [ ! -f "$CREDSTORE/tw_key" ]; then
  warn "No tw_key found — creating empty placeholder"
  touch "$CREDSTORE/tw_key"
fi

[ -f "$CREDSTORE/yt_key" ]   || touch "$CREDSTORE/yt_key"
[ -f "$CREDSTORE/kick_key" ] || touch "$CREDSTORE/kick_key"

chmod 600 "$CREDSTORE"/tw_key "$CREDSTORE"/yt_key "$CREDSTORE"/kick_key
chown root:root "$CREDSTORE"/tw_key "$CREDSTORE"/yt_key "$CREDSTORE"/kick_key
ok "Credstore ready ($CREDSTORE)"

# ── Runtime directory ─────────────────────────────────────────────────────────
step "Setting up runtime directory"
printf 'd /run/247live 0755 vortek vortek -\n' > "$TMPFILES"
ok "tmpfiles.d entry written ($TMPFILES)"
systemd-tmpfiles --create "$TMPFILES" 2>/dev/null || install -d -m 755 -o vortek -g vortek /run/247live
ok "/run/247live ready"

# ── Remove old timer units ────────────────────────────────────────────────────
step "Removing legacy playout-refresh units"
systemctl disable --now playout-refresh.timer playout-refresh.service 2>/dev/null && ok "Disabled old refresh units" || true
for f in playout-refresh.timer playout-refresh.service; do
  rm -f "$SYSTEMD_DIR/$f" && ok "Removed $SYSTEMD_DIR/$f" || true
done

# ── Symlink systemd units ─────────────────────────────────────────────────────
step "Installing systemd units"
for unit in playout.service playout-watchdog.service playout-watchdog.timer; do
  src="$INSTALL_DIR/systemd/$unit"
  dst="$SYSTEMD_DIR/$unit"
  [ -f "$src" ] || die "Missing unit file: $src"
  ln -sf "$src" "$dst"
  ok "Linked $unit"
done

systemctl daemon-reload
ok "systemd reloaded"

# ── Enable watchdog timer ─────────────────────────────────────────────────────
step "Enabling watchdog timer"
systemctl enable --now playout-watchdog.timer
ok "playout-watchdog.timer enabled and started"

# ── Done ──────────────────────────────────────────────────────────────────────
printf '\n%s\n' "─────────────────────────────────────────────────────"
printf '%s\n'   "  Install complete. Next steps:"
printf '\n'
printf '%s\n'   "  1. Add your Twitch stream key:"
printf '%s\n'   "     sudo bash -c 'printf \"%s\" \"live_YOUR_KEY\" > /etc/credstore/tw_key'"
printf '%s\n'   "     sudo chmod 600 /etc/credstore/tw_key"
printf '\n'
printf '%s\n'   "  2. Start streaming:"
printf '%s\n'   "     sudo systemctl enable --now playout"
printf '\n'
printf '%s\n'   "  3. Check status:"
printf '%s\n'   "     bash /opt/247live/scripts/status.sh"
printf '%s\n'   "     journalctl -t 247live -f"
printf '%s\n'   "─────────────────────────────────────────────────────"
