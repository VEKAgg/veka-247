# veka-247 — 24/7 Live Stream

24/7 stream that loops your clips automatically. Drop videos into a folder, they play forever in shuffle. Streams to Twitch, YouTube, and Kick simultaneously via Restreamer.

---

## How it works

```
/srv/clips/  (your videos, NFS from TrueNAS)
     │
     ▼
 ffplayout  (reads clips, encodes, loops 24/7)
     │
     ▼
 Restreamer  rtmp://127.0.0.1:1935/live/<key>
     │
     ├──▶ Twitch   rtmp://live.twitch.tv/app/YOUR_KEY
     ├──▶ YouTube  rtmp://a.rtmp.youtube.com/live2/YOUR_KEY
     └──▶ Kick     rtmp://fa723fc1b171.global-contribute.live-video.net/app/YOUR_KEY
```

- **ffplayout** reads every video from `/srv/clips`, shuffles them, and encodes continuously. No playlist to manage.
- **Restreamer** receives the single RTMP stream from ffplayout and fans it out to all platforms. Add or remove platforms in the Restreamer web UI — no ffplayout changes needed.
- A **watchdog** timer checks every 2 minutes that both services are running and restarts them if not.
- All stream keys are configured in the Restreamer web UI — nothing is stored in this repo.

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

### 3. Set up Restreamer

Open `http://192.168.1.6:8080` and complete the first-time admin setup.

Then:

1. Click **+ Add stream** → create a new channel (e.g. `veka-live`)
2. **Ingest tab** — note the stream key shown (you'll need it in the next step)
3. **Outputs tab** → Add output → **Twitch** → paste your Twitch stream key
   - Get your key from: Twitch → Creator Dashboard → Settings → Stream → Stream Key
4. Click **Save** → **Start channel**

Restreamer is now listening on `rtmp://127.0.0.1:1935/live/<your-key>`.

### 4. Configure ffplayout output

Open `http://192.168.1.6:8787` → log in (`admin` / `admin`) → **Settings → Playout**

| Section | Field | Value |
|---|---|---|
| Storage | Mode | Folder |
| Storage | Shuffle | ✓ checked |
| Text | Add Text | ✗ unchecked |
| Output | Mode | stream |
| Output | Output Parameter | *(see below)* |

Paste this into **Output Parameter** (replace `YOUR_RESTREAMER_KEY` with the key from step 3):
```
-c:v libx264 -preset superfast -profile:v high -b:v 2500k -maxrate 2500k -bufsize 5000k -g 60 -keyint_min 60 -r 30 -pix_fmt yuv420p -c:a aac -b:a 128k -ar 44100 -f flv rtmp://127.0.0.1:1935/live/YOUR_RESTREAMER_KEY
```

Hit **Save**.

### 5. Start streaming

Go to **Player** tab → press **Start**.

Check logs to confirm it's pushing:
```bash
journalctl -u ffplayout -f
```

### 6. Add clips

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

## Adding platforms (YouTube, Kick, etc.)

Since ffplayout pushes to Restreamer, adding a new platform requires zero ffplayout changes:

1. Open `http://192.168.1.6:8080` → your channel → **Outputs tab**
2. Click **Add output** → select platform → paste stream key
3. Save — Restreamer immediately starts pushing to the new platform

**Platform RTMP URLs:**

| Platform | RTMP URL |
|---|---|
| Twitch | `rtmp://live.twitch.tv/app/YOUR_KEY` |
| YouTube | `rtmp://a.rtmp.youtube.com/live2/YOUR_KEY` |
| Kick | `rtmp://fa723fc1b171.global-contribute.live-video.net/app/YOUR_KEY` |

Get keys from each platform's creator dashboard / stream settings.

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
- [x] Restreamer as RTMP hub (ffplayout → Restreamer → platforms)
- [x] Twitch output via Restreamer
- [x] Auto-restart watchdog
- [ ] YouTube output (add in Restreamer UI)
- [ ] Kick output (add in Restreamer UI)
- [ ] Lower-thirds overlay (clip name / submitter)
- [ ] Automated clip submission (Discord bot → TrueNAS)
- [ ] Clip normalization on upload
- [ ] Schedule-based playout (specific clips at specific times)
