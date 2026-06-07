# veka-247 — 24/7 Live Stream (rta branch)

Docker-based 24/7 livestream stack using **ffplayout** for seamless clip playout and **datarhei Restreamer** for multi-platform output.

> **Branch:** `rta` — replaces the bare-metal bash+ffmpeg stack from `dev` with a proper Docker-based playout engine that eliminates stream drops between clips.

---

## Architecture

```
TrueNAS (192.168.1.98)
  /mnt/tank/247Live/
        |
        | NFS4
        v
247Live VM (192.168.1.6)
  /srv/clips/
        |
        v
  +-----------+        RTMP         +-------------+
  | ffplayout |  --------------->   | Restreamer  |
  | :8787 UI  |  rtmp://restreamer  | :8080 UI    |
  +-----------+    :1935/live/247   +------+------+
                                          |
                          +---------------+---------------+
                          v               v               v
                       Twitch          YouTube           Kick
```

**ffplayout** reads clips from `/srv/clips`, plays them in a seamless loop (no stream drops), and pushes a single encoded RTMP stream to the local Restreamer container. **Restreamer** receives that stream and fans it out to all platforms simultaneously.

---

## Infrastructure

| Component | IP | Path |
|---|---|---|
| TrueNAS | 192.168.1.98 | /mnt/tank/247Live |
| 247Live VM | 192.168.1.6 | /srv/clips (NFS mount) |
| ffplayout UI | 192.168.1.6:8787 | Docker container |
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

### 4. Add clips

Drop MP4/MKV files into `/srv/clips` via SMB, WinSCP, or scp:

```bash
scp clip.mp4 vortek@192.168.1.6:/srv/clips/
```

ffplayout picks them up automatically — no restart needed.

---

## Project Structure

```
veka-247/
├── config/
│   └── ffplayout.yml        # ffplayout config (output quality, storage path, shuffle)
├── docker/
│   └── docker-compose.yml   # ffplayout + Restreamer containers
├── overlays/                # Overlay images (for future lower-thirds)
├── scripts/
│   ├── install.sh           # One-command install
│   ├── normalize_clips.sh   # Pre-process raw clips to consistent spec
│   └── status.sh            # Health check
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

To switch to 1080p60, edit `config/ffplayout.yml` and change `width`, `height`, `fps`, and bitrate values, then restart the container.

---

## Managing the Stack

```bash
# Check status
bash scripts/status.sh

# View live logs
docker logs -f ffplayout
docker logs -f restreamer

# Restart everything
cd /opt/247live/docker && docker compose restart

# Stop
cd /opt/247live/docker && docker compose down

# Update images
cd /opt/247live/docker && docker compose pull && docker compose up -d
```

---

## Credential Handling

Stream keys are stored **inside Restreamer** (encrypted in `/opt/247live/restreamer/config`) and configured via the web UI. They are never stored in scripts, env files, or `/etc/credstore`.

---

## Roadmap

- [x] Seamless 24/7 clip playout (ffplayout)
- [x] Multi-platform output (Restreamer)
- [x] Web UI for both services
- [ ] Lower-thirds overlay (clip name + submitter)
- [ ] Automated clip submission (Discord bot / web form → TrueNAS)
- [ ] Clip normalization pipeline on upload
- [ ] Schedule-based playout (specific clips at specific times)
