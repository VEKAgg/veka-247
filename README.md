# veka-247 — 24/7 Live Stream (rta branch)

24/7 livestream stack using **ffplayout** (native install) for seamless clip playout and **datarhei Restreamer** (Docker) for multi-platform output.

> **Branch:** `rta` — ffplayout runs natively via .deb package, Restreamer runs in Docker.

---

## Architecture

```
TrueNAS (192.168.1.98)
  /srv/clips/
        |
        | NFS4
        v
247Live VM (192.168.1.6)
  /srv/clips/
        |
        v
  +-----------+        RTMP         +-------------+
  | ffplayout |  --------------->   | Restreamer  |
  | (systemd) |  rtmp://127.0.0.1   | :8080 UI    |
  | :8787 UI  |  :1935/live/247live +------+------+
  +-----------+                             |
                           +---------------+---------------+
                           v               v               v
                        Twitch          YouTube           Kick
```

**ffplayout** runs as a systemd service, reads clips from `/srv/clips`, plays them in a seamless loop, and pushes a single encoded RTMP stream to the local Restreamer container. **Restreamer** (Docker) receives that stream and fans it out to all platforms simultaneously.

---

## Infrastructure

| Component | IP | Path |
|---|---|---|
| TrueNAS | 192.168.1.98 | /srv/clips |
| 247Live VM | 192.168.1.6 | /srv/clips (NFS mount) |
| ffplayout UI | 192.168.1.6:8787 | Native systemd service |
| Restreamer UI | 192.168.1.6:8080 | Docker container |

---

## Quick Start

### 1. Clone and install

```bash
git clone -b rta https://github.com/VEKAgg/veka-247 /opt/247live
cd /opt/247live
sudo bash scripts/install.sh
```

### 2. Open the web UIs

- **ffplayout:** http://192.168.1.6:8787
- **Restreamer:** http://192.168.1.6:8080

### 3. Add stream keys (Restreamer UI)

In Restreamer → Outputs → Add destination:
- Twitch: `rtmp://live.twitch.tv/app/YOUR_KEY`
- YouTube: `rtmp://a.rtmp.youtube.com/live2/YOUR_KEY`
- Kick: `rtmp://fa723fc1b171.global-contribute.live-video.net/app/YOUR_KEY`

### 4. Add and normalize clips

If your clips have mixed resolutions or framerates, normalize them first (prevents frame freezes at cut points):

```bash
mkdir -p /srv/clips/raw
# copy your raw clips into /srv/clips/raw, then:
bash scripts/normalize_clips.sh
# normalized files land in /srv/clips as *_norm.mp4
```

Or drop already-compatible MP4s (720p30, AAC audio) directly into `/srv/clips`:

```bash
scp clip.mp4 youruser@192.168.1.6:/srv/clips/
```

ffplayout picks up new clips automatically — no restart needed.

---

## Project Structure

```
veka-247/
├── config/
│   └── ffplayout.yml        # ffplayout config (output quality, storage path, shuffle)
├── docker/
│   └── docker-compose.yml   # Restreamer container only
├── overlays/                # Overlay images (for future lower-thirds)
├── scripts/
│   ├── install.sh           # One-command install (native ffplayout + Docker Restreamer)
│   ├── normalize_clips.sh   # Pre-process raw clips to consistent spec
│   ├── status.sh            # Health check
│   └── watchdog.sh          # Auto-restart logic (run by systemd timer)
├── systemd/
│   ├── ffplayout-watchdog.service
│   └── ffplayout-watchdog.timer   # Fires every 2 min
└── .env.example             # Infrastructure reference (no secrets)
```

---

## Normalizing Clips

If clips have different resolutions, framerates, or timebases, pre-process them first to avoid frame freezes at cut points:

```bash
mkdir -p /srv/clips/raw
# move raw clips into /srv/clips/raw, then:
bash scripts/normalize_clips.sh
# normalized files appear in /srv/clips as *_norm.mp4
```

---

## Stream Quality

Configured in `config/ffplayout.yml` — default is **720p30 @ 2500k**:

| Setting | Value |
|---|---|
| Resolution | 1280x720 |
| FPS | 30 |
| Video bitrate | 2500k |
| Audio | AAC 128k 44100Hz |
| Encoder | libx264 superfast |

To switch to 1080p60, edit `config/ffplayout.yml` and change `width`, `height`, `fps`, and bitrate values, then restart the service:

```bash
sudo systemctl restart ffplayout
```

---

## Managing the Stack

```bash
# Check status
bash scripts/status.sh

# ffplayout (native systemd service)
sudo systemctl status ffplayout
sudo systemctl restart ffplayout
journalctl -u ffplayout -f           # live logs

# Restreamer (Docker)
docker logs -f restreamer
cd /opt/247live/docker && docker compose restart
cd /opt/247live/docker && docker compose down
cd /opt/247live/docker && docker compose pull && docker compose up -d
```

---

## Credential Handling

Stream keys are stored **inside Restreamer** (encrypted in `/opt/247live/restreamer/config`) and configured via the web UI. They are never stored in scripts, env files, or `/etc/credstore`.

---

## Watchdog

A systemd timer fires every 2 minutes and checks:
- ffplayout service is active (restarts it if not)
- Restreamer RTMP port 1935 is listening (restarts container if not)
- At least one clip exists in `/srv/clips`

View watchdog logs:
```bash
journalctl -u ffplayout-watchdog -f
```

---

## Roadmap

- [x] Seamless 24/7 clip playout (ffplayout)
- [x] Multi-platform output (Restreamer)
- [x] Web UI for both services
- [x] Auto-restart watchdog
- [ ] Lower-thirds overlay (clip name + submitter)
- [ ] Automated clip submission (Discord bot / web form → TrueNAS)
- [ ] Clip normalization pipeline on upload
- [ ] Schedule-based playout (specific clips at specific times)
