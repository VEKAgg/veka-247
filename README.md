# 247Live — 24/7 Automated Live Streaming Playout

Continuous live stream that reads video clips from TrueNAS and pushes to Twitch (multi-platform ready).

## Architecture

```
TrueNAS (192.168.1.98)
  └── /mnt/tank/247Live/        ← Drop clips here via SMB/WinSCP
          │ NFS4
          ▼
247Live VM (192.168.1.6)
  └── /srv/clips/               ← NFS mount
          │
          ▼
  generate_playlist.sh          ← Randomizes clip order
          │
          ▼
  playout.sh                    ← Loops clips via ffmpeg, reshuffles on each cycle
          │
          ▼
  rtmp://live.twitch.tv/...     ← Streams to Twitch (or multi-platform via tee)
```

## Quick Start

```bash
# Start streaming
sudo systemctl start playout

# Watch live logs
sudo journalctl -fu playout

# Stop streaming
sudo systemctl stop playout
```

## Adding Video Clips

Upload `.mp4`, `.mkv`, `.mov`, `.avi`, `.flv`, or `.ts` files to the `247Live` dataset on TrueNAS.

**From Windows (recommended for clients):**
- Map a network drive to `\\192.168.1.98\247Live`
- Or use WinSCP: host `192.168.1.98`, port `22`, user `root`

**From Linux/Mac:**
```bash
scp *.mp4 root@192.168.1.98:/mnt/tank/247Live/
```

New clips are picked up automatically within 6 hours (timer), or immediately on service restart.

## How It Works

1. `generate_playlist.sh` scans `/srv/clips` for video files, randomizes the order, writes a playlist to `/tmp/playlist.txt`
2. `playout.sh` reads the playlist via ffmpeg, encodes to 1080p H.264, and pushes via RTMP
3. When ffmpeg finishes all clips or crashes, `playout.sh` reshuffles and restarts automatically (inner loop)
4. `playout-refresh.timer` restarts the service every 6 hours to pick up new clips from TrueNAS
5. `playout.service` runs as `vortek` user with credentials passed via systemd `LoadCredential`

## Stream Keys

Keys are stored securely in `/etc/credstore/` (root-only, chmod 600).
They are passed to the service at runtime via systemd `LoadCredential` — never in scripts or version control.

### Update a key

```bash
# YouTube
sudo bash -c 'echo -n "rtmp://a.rtmp.youtube.com/live2/YOUR_KEY" > /etc/credstore/yt_key'

# Twitch
sudo bash -c 'echo -n "rtmp://live.twitch.tv/app/YOUR_KEY" > /etc/credstore/tw_key'

# Kick
sudo bash -c 'echo -n "rtmp://fa723fc1b171.global-contribute.live-video.net/app/YOUR_KEY" > /etc/credstore/kick_key'

sudo chmod 600 /etc/credstore/*
sudo systemctl restart playout
```

### Where to find your stream keys

| Platform | Location |
|---|---|
| YouTube | YouTube Studio → Go Live → Stream tab |
| Twitch | Dashboard → Settings → Stream |
| Kick | Creator Dashboard → Settings → Stream |

### Enable multi-platform

Edit `playout.sh` and replace the `-f flv` line with:

```bash
-f tee "[f=flv]rtmp://live.twitch.tv/app/${TW_KEY}|[f=flv]rtmp://a.rtmp.youtube.com/live2/${YT_KEY}|[f=flv]rtmp://fa723fc1b171.global-contribute.live-video.net/app/${KICK_KEY}"
```

Then uncomment the `LoadCredential` lines in `systemd/playout.service` and add the keys to `/etc/credstore/`.

## Timer

The playout auto-refreshes every 6 hours via systemd timer:

```bash
# Check timer status
sudo systemctl list-timers --all | grep playout

# Manually trigger a refresh
sudo systemctl start playout-refresh.service

# Change interval (edit the timer file)
sudo nano /opt/247live/systemd/playout-refresh.timer
sudo systemctl daemon-reload
sudo systemctl restart playout-refresh.timer
```

## Troubleshooting

```bash
# Service status
sudo systemctl status playout

# Check NFS mount
mount | grep nfs
ls /srv/clips/

# Count available clips
find /srv/clips -type f \( -name '*.mp4' -o -name '*.mkv' -o -name '*.mov' \) | wc -l

# Regenerate playlist manually
/opt/247live/scripts/generate_playlist.sh
cat /tmp/playlist.txt

# Test network to streaming platform
nc -zv live.twitch.tv 1935

# View recent logs
sudo journalctl -u playout --no-pager -n 50
```

## Project Structure

```
/opt/247live/
├── scripts/
│   ├── generate_playlist.sh    # Scans clips, randomizes order, writes playlist
│   └── playout.sh              # FFmpeg loop — encodes and pushes to RTMP
├── systemd/
│   ├── playout.service         # Main streaming service (symlinked to /etc/systemd/system/)
│   ├── playout-refresh.timer   # Auto-restart every 6 hours
│   └── playout-refresh.service # Restarts playout when timer fires
├── .env.example                # Key template (no real keys committed)
├── .gitignore                  # Excludes secrets from version control
└── README.md                   # This file
```

## Secrets Storage

- `/etc/credstore/yt_key` — YouTube RTMP URL
- `/etc/credstore/tw_key` — Twitch RTMP URL
- `/etc/credstore/kick_key` — Kick RTMP URL
- Permissions: `root:root 700` (directory), `600` (files)
- Passed to service via `LoadCredential` in the systemd unit
- Never in scripts, environment files, or git
