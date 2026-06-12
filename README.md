# veka-247 — 24/7 Live Stream

24/7 Twitch stream that loops your clips automatically. Drop videos in a folder, they play forever in shuffle.

---

## How it works

```
/srv/clips/  (your videos)
     │
     ▼
 ffplayout        ← reads clips, encodes, loops 24/7
     │
     ▼
 Twitch RTMP      ← rtmp://live.twitch.tv/app/YOUR_KEY
```

- **ffplayout** is the engine. It reads every video from `/srv/clips`, shuffles them, and streams continuously. No playlist to manage — just drop files in and they play.
- Your **Twitch stream key** lives in a `.env` file on the server only. It never touches the repo.
- A **watchdog** timer checks every 2 minutes that everything is still running and restarts it if not.
- **Restreamer** (optional) is included if you ever want to stream to YouTube or Kick simultaneously. Not required for Twitch-only.

---

## Setup (fresh server)

### 1. Clone the repo

```bash
sudo mkdir -p /opt/247live
sudo chown $USER:$USER /opt/247live
git clone -b rta https://github.com/VEKAgg/veka-247 /opt/247live
cd /opt/247live
```

### 2. Create your .env with your Twitch key

```bash
cp .env.example .env
nano .env
```

Set `TWITCH_KEY` to your stream key. Get it from:
**Twitch → Creator Dashboard → Settings → Stream → Stream Key**

```
TWITCH_KEY=live_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 3. Run install

```bash
sudo bash scripts/install.sh
```

That's it. The stream starts automatically once you have clips.

### 4. Add clips

```bash
# from your local machine:
scp myclip.mp4 vortek@192.168.1.6:/srv/clips/

# or normalize first if clips have mixed resolutions/framerates:
bash scripts/normalize_clips.sh
```

---

## What each script does

| Script | What it does | When to run |
|---|---|---|
| `scripts/install.sh` | Installs everything, reads `.env`, injects your stream key | Once on a fresh server, or after a clean wipe |
| `scripts/normalize_clips.sh` | Converts raw clips to consistent 720p30 format | Before adding clips that have different resolutions or framerates |
| `scripts/status.sh` | Shows if ffplayout and Docker are running, how many clips you have | Any time you want to check health |
| `scripts/watchdog.sh` | Checks ffplayout is alive, restarts it if not | Runs automatically every 2 min via systemd — you don't call this manually |

---

## Daily use

```bash
# Check everything is running
bash scripts/status.sh

# Watch live logs (see which clip is playing)
journalctl -u ffplayout -f

# Add a clip
scp clip.mp4 vortek@192.168.1.6:/srv/clips/
# ffplayout picks it up automatically — no restart needed

# Restart ffplayout manually
sudo systemctl restart ffplayout

# Restart Restreamer (if using multi-platform)
cd /opt/247live/docker && docker compose restart
```

---

## Is the playlist rolling?

Yes — automatically. ffplayout runs in **folder mode**: it reads every file in `/srv/clips`, shuffles them, and loops continuously. There is no playlist file to generate or manage. When you add a new clip, ffplayout picks it up on its next cycle without any restart.

To confirm it's working:
```bash
journalctl -u ffplayout -f
```
You'll see log lines showing which clip is currently playing and what's up next.

---

## Stream quality

Default: **720p30 @ 2500k** — safe for Twitch, works on a 2-core VM.

| Setting | Value |
|---|---|
| Resolution | 1280×720 |
| FPS | 30 |
| Video bitrate | 2500k |
| Audio | AAC 128k 44100Hz |
| Encoder | libx264 superfast |

To change quality, edit `config/ffplayout.yml`, then re-run `sudo bash scripts/install.sh`.

---

## Architecture

```
TrueNAS (192.168.1.98)
  /srv/clips/
        │  NFS
        ▼
247Live VM (192.168.1.6)
  /srv/clips/
        │
        ▼
  ffplayout (systemd)   →   rtmp://live.twitch.tv/app/KEY   →   Twitch
  :8787 web UI
        │
        ▼ (optional, for YouTube/Kick)
  Restreamer (Docker)
  :8080 web UI
```

---

## Credential handling

Stream keys are in `/opt/247live/.env` on the server only. That file is gitignored and never committed. The repo contains only a `.env.example` with placeholder values.

---

## Watchdog

A systemd timer fires every 2 minutes:
- Checks ffplayout service is active (restarts if not)
- Checks Restreamer RTMP port 1935 is listening
- Warns if `/srv/clips` is empty

View watchdog logs:
```bash
journalctl -u ffplayout-watchdog -f
```

---

## Project structure

```
veka-247/
├── .env.example             ← copy to .env, fill in TWITCH_KEY
├── config/
│   └── ffplayout.yml        ← encoding settings (stream key injected by install.sh)
├── docker/
│   └── docker-compose.yml   ← Restreamer (optional multi-platform)
├── scripts/
│   ├── install.sh           ← one-command setup
│   ├── normalize_clips.sh   ← pre-process clips with mixed formats
│   ├── status.sh            ← health check
│   └── watchdog.sh          ← auto-restart (runs via systemd timer)
├── systemd/
│   ├── ffplayout-watchdog.service
│   └── ffplayout-watchdog.timer
└── overlays/                ← overlay images (future use)
```

---

## Roadmap

- [x] Seamless 24/7 clip playout (ffplayout)
- [x] Direct Twitch RTMP output
- [x] Stream key in .env, never in repo
- [x] Auto-restart watchdog
- [x] Optional multi-platform output (Restreamer)
- [ ] Lower-thirds overlay (clip name / submitter)
- [ ] Automated clip submission (Discord bot → TrueNAS)
- [ ] Clip normalization on upload
- [ ] Schedule-based playout (specific clips at specific times)
