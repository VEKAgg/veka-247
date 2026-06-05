# 247live — 24/7 Automated Live Stream

Continuous live stream that reads video clips from TrueNAS and pushes to Twitch (with optional YouTube and Kick). Pure bash + ffmpeg + systemd. No dependencies beyond what a standard Linux server already has.

## Architecture

```
TrueNAS (192.168.1.98)
  └── /mnt/tank/247Live/        ← Drop clips here via SMB / WinSCP
          │ NFS
          ▼
247Live VM (192.168.1.6)
  └── /srv/clips/               ← NFS mount point

  generate_playlist.sh          ← Validates + randomizes clips, builds playlist
          │
          ▼
  playout.sh                    ← Streams via ffmpeg, reshuffles on each cycle
          │
          ▼
  rtmp://live.twitch.tv/...     ← Twitch (+ YouTube / Kick if configured)

  watchdog.sh (every 5 min)     ← Detects hung ffmpeg, NFS drops, restarts as needed
  status.sh                     ← One-command health check
```

## Prerequisites

- `ffmpeg` and `ffprobe` installed
- NFS client installed; `/srv/clips` mounted from TrueNAS
- `vortek` user exists on the server
- Files installed at `/opt/247live/`

## Installation

```bash
# Copy repo to server
sudo cp -r . /opt/247live

# Run the install script (sets up systemd units, credstore, runtime dir)
sudo bash /opt/247live/scripts/install.sh
```

The install script:
- Marks all scripts executable
- Creates `/etc/credstore/` with correct permissions
- Writes a `tmpfiles.d` entry so `/run/247live` survives reboots
- Symlinks systemd units into `/etc/systemd/system/`
- Enables and starts the watchdog timer

## Stream Keys

Keys live in `/etc/credstore/` (root-only, never in scripts or git).

```bash
# Twitch (required)
sudo bash -c 'printf "%s" "live_YOUR_KEY_HERE" > /etc/credstore/tw_key'
sudo chmod 600 /etc/credstore/tw_key

# YouTube (optional — skip to disable)
sudo bash -c 'printf "%s" "YOUR_YT_KEY" > /etc/credstore/yt_key'
sudo chmod 600 /etc/credstore/yt_key

# Kick (optional — skip to disable)
sudo bash -c 'printf "%s" "YOUR_KICK_KEY" > /etc/credstore/kick_key'
sudo chmod 600 /etc/credstore/kick_key
```

Multi-platform is automatic — if a key file is non-empty, that platform is included. Empty or missing = silently skipped.

## Start Streaming

```bash
sudo systemctl enable --now playout
```

## Daily Commands

```bash
# Stream health summary
bash /opt/247live/scripts/status.sh

# Live logs (clip changes, errors)
journalctl -t 247live -f

# Stop / start / restart
sudo systemctl stop playout
sudo systemctl start playout
sudo systemctl restart playout

# Check watchdog
journalctl -t 247live-watchdog --since "1h ago"
```

## Configuration

All settings live in `config/stream.conf`. Key options:

| Variable | Default | Description |
|---|---|---|
| `CLIP_DIR` | `/srv/clips` | Where clips are read from |
| `QUALITY_PROFILE` | `720p30` | `720p30` or `1080p60` |
| `VALIDATE_CLIPS` | `true` | ffprobe-check clips before adding to playlist |
| `RESTART_DELAY` | `3` | Seconds to wait before reshuffling after ffmpeg exits |

For a local override that isn't tracked in git, create `config/stream.conf.local` — `stream.conf` sources it at the end if it exists.

## Adding Clips

Upload `.mp4`, `.mkv`, `.mov`, `.avi`, `.flv`, or `.ts` files to the `247Live` dataset on TrueNAS.

**From Windows:** Map `\\192.168.1.98\247Live` as a network drive, or use WinSCP (host `192.168.1.98`, port 22, user `root`).

**From Linux/Mac:**
```bash
scp *.mp4 root@192.168.1.98:/mnt/tank/247Live/
```

New clips are picked up on the next ffmpeg restart (automatic when the current playlist runs out, or force it with `sudo systemctl restart playout`).

## Overlay

Place a transparent PNG named `overlay.png` in the `overlays/` directory to burn a static graphic into the stream. See `overlays/README.md` for sizing and positioning details. Restart the service after adding or changing the overlay.

## Quality Profiles

Edit `config/stream.conf`:

| Profile | Resolution | FPS | Bitrate | Notes |
|---|---|---|---|---|
| `720p30` | 1280×720 | 30 | 2500 kbps | Default — works on modest hardware |
| `1080p60` | 1920×1080 | 60 | 6000 kbps | Requires Twitch Partner or Affiliate |

## Watchdog

`playout-watchdog.timer` fires every 5 minutes and checks:
1. ffmpeg PID is alive
2. NFS mount is responsive
3. ffmpeg CPU isn't stalled (two consecutive near-zero readings = hung)

If any check fails, it restarts `playout.service` automatically and logs the reason to journalctl.

## Troubleshooting

**Stream not starting:**
```bash
sudo systemctl status playout
journalctl -u playout --no-pager -n 50
```

**NFS not mounted:**
```bash
mount | grep nfs
sudo mount -a
ls /srv/clips/
```

**Check what's playing:**
```bash
journalctl -t 247live --since "5 min ago" | grep "NOW PLAYING"
```

**Manually regenerate playlist:**
```bash
CREDENTIALS_DIRECTORY=/etc/credstore bash /opt/247live/scripts/generate_playlist.sh
```

**Test stream reachability:**
```bash
nc -zv live.twitch.tv 1935
```

**Rotate a stream key:**
```bash
sudo bash -c 'printf "%s" "NEW_KEY" > /etc/credstore/tw_key'
sudo chmod 600 /etc/credstore/tw_key
sudo systemctl restart playout
```

## Project Structure

```
/opt/247live/
├── config/
│   └── stream.conf             # All settings — edit this, not the scripts
├── scripts/
│   ├── install.sh              # One-shot server setup
│   ├── playout.sh              # Main streaming loop (ffmpeg + signal handling)
│   ├── generate_playlist.sh    # Clip validation + randomized playlist builder
│   ├── watchdog.sh             # Health monitor — restarts on stall/NFS drop
│   └── status.sh               # Stream health summary
├── systemd/
│   ├── playout.service         # Main service (symlinked to /etc/systemd/system/)
│   ├── playout-watchdog.service
│   └── playout-watchdog.timer  # Fires every 5 minutes
├── overlays/
│   └── README.md               # How to add a stream overlay
├── .env.example                # Explains key setup (keys go in /etc/credstore/)
└── README.md
```

## Secrets

- `/etc/credstore/tw_key` — Twitch stream key
- `/etc/credstore/yt_key` — YouTube stream key (empty = disabled)
- `/etc/credstore/kick_key` — Kick stream key (empty = disabled)
- Permissions: directory `700 root:root`, files `600 root:root`
- Injected at runtime via systemd `LoadCredential` — never in scripts or git
