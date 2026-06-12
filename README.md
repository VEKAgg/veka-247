# veka-247 — 24/7 Live Stream

24/7 Twitch stream that loops your clips automatically. Drop videos into a folder, they play forever in shuffle.

---

## How it works

```
/srv/clips/  (your videos, NFS from TrueNAS)
     │
     ▼
 ffplayout  (reads clips, encodes, loops 24/7 — configured via web UI)
     │
     ├──▶ Twitch   rtmp://live.twitch.tv/app/YOUR_KEY
     │
     └──▶ (optional) Restreamer → YouTube / Kick
```

- **ffplayout** reads every video from `/srv/clips`, shuffles them, and streams continuously. No playlist to manage — drop files in and they play.
- All channel settings (output URL, stream key, encoding, mode) are configured in the **ffplayout web UI** — no config files to edit.
- A **watchdog** timer checks every 2 minutes that everything is running and restarts if not.
- **Restreamer** is optional — only needed if you want to stream to YouTube or Kick at the same time as Twitch.

---

## Setup (fresh server)

### 1. Clone

```bash
sudo mkdir -p /opt/247live
sudo chown $USER:$USER /opt/247live
git clone -b rta https://github.com/VEKAgg/veka-247 /opt/247live
cd /opt/247live
```

### 2. Install

```bash
sudo bash scripts/install.sh
```

### 3. Configure ffplayout output

Open `http://192.168.1.6:8787` → log in (`admin` / `admin`) → **Settings → Playout**

Make these changes:

| Section | Field | Value |
|---|---|---|
| Storage | Mode | Folder |
| Storage | Shuffle | ✓ checked |
| Text | Add Text | ✗ unchecked |
| Output | Mode | stream |
| Output | Output Parameter | *(see below)* |

Paste this into **Output Parameter** (replace `YOUR_TWITCH_KEY`):
```
-c:v libx264 -preset superfast -profile:v high -b:v 2500k -maxrate 2500k -bufsize 5000k -g 60 -keyint_min 60 -r 30 -pix_fmt yuv420p -c:a aac -b:a 128k -ar 44100 -f flv rtmp://live.twitch.tv/app/YOUR_TWITCH_KEY
```

Get your Twitch key from: **Twitch → Creator Dashboard → Settings → Stream → Stream Key**

Hit **Save**.

### 4. Start streaming

Go to **Player** tab → press **Start**.

Check logs to confirm it's pushing:
```bash
journalctl -u ffplayout -f
```

### 5. Add clips

```bash
scp myclip.mp4 vortek@192.168.1.6:/srv/clips/
```

ffplayout picks up new clips automatically — no restart needed.

---

## What each script does

| Script | What it does | When to run |
|---|---|---|
| `scripts/install.sh` | Installs ffplayout + Restreamer, creates dirs, starts services | Once on a fresh server |
| `scripts/normalize_clips.sh` | Converts clips to consistent 720p30 format | Before adding clips with mixed resolutions/framerates |
| `scripts/status.sh` | Shows if services are running and how many clips exist | Any time you want to check health |
| `scripts/watchdog.sh` | Checks ffplayout is alive, restarts if not | Runs automatically every 2 min — do not call manually |

---

## Normalizing clips

If your clips have different resolutions or framerates, pre-process them first to avoid frame freezes at cut points:

```bash
mkdir -p /srv/clips/raw
# move raw clips into /srv/clips/raw, then:
bash scripts/normalize_clips.sh
# normalized files appear in /srv/clips as *_norm.mp4
```

---

## Daily use

```bash
# Check everything is running
bash scripts/status.sh

# Watch live logs (see which clip is playing)
journalctl -u ffplayout -f

# Restart ffplayout
sudo systemctl restart ffplayout

# Restart Restreamer
cd /opt/247live/docker && docker compose restart
```

---

## Multi-platform streaming (optional)

Restreamer is already installed and running at `http://192.168.1.6:8080`. To stream to YouTube or Kick simultaneously:

1. Open Restreamer UI → configure it to ingest from ffplayout
2. In ffplayout Output Parameter, push to Restreamer instead of Twitch directly:
   ```
   rtmp://127.0.0.1:1935/live/YOUR_RESTREAMER_KEY
   ```
3. Restreamer fans out to all platforms

---

## Stream quality

Default: **720p30 @ 2500k** — works on a 2-core VM, safe for Twitch.

| Setting | Value |
|---|---|
| Resolution | 1280×720 |
| FPS | 30 |
| Video bitrate | 2500k |
| Audio | AAC 128k 44100Hz |
| Encoder | libx264 superfast |

To change, update the Output Parameter in the ffplayout UI and restart the player.

---

## Watchdog

Fires every 2 min via systemd timer. Checks:
- ffplayout is active (restarts if not)
- Restreamer RTMP port 1935 is listening
- `/srv/clips` has at least one clip

```bash
journalctl -u ffplayout-watchdog -f
```

---

## Project structure

```
veka-247/
├── .env.example             ← infrastructure reference (no secrets)
├── docker/
│   └── docker-compose.yml   ← Restreamer (optional multi-platform)
├── overlays/                ← overlay images (future use)
├── scripts/
│   ├── install.sh           ← one-command setup
│   ├── normalize_clips.sh   ← pre-process mixed-format clips
│   ├── status.sh            ← health check
│   └── watchdog.sh          ← auto-restart (runs via systemd timer)
└── systemd/
    ├── ffplayout-watchdog.service
    └── ffplayout-watchdog.timer
```

---

## Roadmap

- [x] Seamless 24/7 clip playout (ffplayout folder mode)
- [x] Direct Twitch RTMP output
- [x] Auto-restart watchdog
- [x] Optional multi-platform output (Restreamer)
- [ ] Lower-thirds overlay (clip name / submitter)
- [ ] Automated clip submission (Discord bot → TrueNAS)
- [ ] Clip normalization on upload
- [ ] Schedule-based playout (specific clips at specific times)
