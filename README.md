# veka-247 — Multi-Channel 24/7 Streaming Server

Docker-based multi-channel livestream stack with a custom dashboard, alert system, and IRL relay.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                 Svelte Web Dashboard                      │
│  Channels │ Alerts │ IRL │ Clips │ Preview │ Platforms    │
└──────────────────────────┬───────────────────────────────┘
                           │ REST API + WebSocket
┌──────────────────────────▼───────────────────────────────┐
│              Python FastAPI Backend                        │
│  Channel Manager │ Alert Engine │ Overlay Manager          │
│  Clip Manager │ IRL Relay │ PostgreSQL                     │
└───────┬──────────────────┬──────────────────┬────────────┘
        │                  │                  │
   ┌────▼────┐        ┌─────▼─────┐     ┌────▼────┐
   │ffplayout│        │ffplayout  │     │ffplayout│
   │  TTTR   │        │  IGFV/FH6 │     │  VA     │
   └────┬────┘        └─────┬─────┘     └────┬────┘
        └─────────┬─────────┴─────────────────┘
                  │ RTMP
        ┌─────────▼─────────┐
        │    Restreamer      │
        └─────────┬─────────┘
                  │
     ┌────────────┼────────────┐
     ▼            ▼            ▼
  Twitch       YouTube       Kick
  (Mumbai)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phone (IRL) ──RTMP──→ MediaMTX ──→ FFmpeg ──→ Platforms
```

---

## Channels

| Channel | Content | Clips Folder | ffplayout Port |
|---------|---------|-------------|----------------|
| TTTR | GTA5 Roleplay | `/srv/clips/tttr` | 8787 |
| IGFV | Elite Dangerous | `/srv/clips/igfv` | 8788 |
| FH6 | Forza Horizon 6 | `/srv/clips/fh6` | 8789 |
| VA | Rocket League | `/srv/clips/va` | 8790 |

---

## Quick Start

```bash
# Clone and install
git clone <repo-url> /opt/247live
cd /opt/247live
sudo bash scripts/install.sh
```

### Access the services

| Service | URL |
|---------|-----|
| Dashboard | `http://<VM_IP>:3000` |
| Backend API | `http://<VM_IP>:8000` |
| Restreamer | `http://<VM_IP>:8080` |
| MediaMTX HLS | `http://<VM_IP>:8888` |
| IRL Ingest | `rtmp://<VM_IP>:1935/live/irl` |

---

## Stream Keys

Stream keys are configured in the **Restreamer web UI** (`:8080`) for 24/7 channels, or via the **Dashboard** (`:3000`) for the new system.

### Twitch Mumbai

| Server | RTMP URL |
|--------|----------|
| Mumbai | `rtmp://aps30.contribute.live-video.net/app` |
| Auto-route | `rtmp://ingest.global-contribute.live-video.net/app` |

### YouTube

| Server | RTMP URL |
|--------|----------|
| Primary | `rtmp://a.rtmp.youtube.com/live2` |
| Backup | `rtmp://b.rtmp.youtube.com/live2?backup=1` |

### Kick

Per-account URL from your Kick dashboard. Format:
`rtmps://{account-id}.global-contribute.live-video.net:443/app`

---

## IRL Streaming

Stream from your phone using Moblin, PRISM Live, or any RTMP app:

```
RTMP URL: rtmp://your-server:1935/live/irl
```

No stream key required for IRL ingest.

---

## Database

PostgreSQL 16 with:
- Channel management
- Per-channel platform configuration
- Clip tracking
- Alert templates (Streamlabs + StreamElements webhooks)
- Stream session history (partitioned by month)
- LISTEN/NOTIFY for real-time WebSocket updates

---

## Project Structure

```
veka-247/
├── config/                    # ffplayout + MediaMTX configs
│   ├── ffplayout-tttr.yml
│   ├── ffplayout-igfv.yml
│   ├── ffplayout-fh6.yml
│   ├── ffplayout-va.yml
│   └── mediamtx.yml
├── server/                    # Python FastAPI backend
│   ├── main.py
│   ├── models.py
│   ├── routers/
│   ├── services/
│   └── sql/init.sql
├── dashboard/                 # Svelte web dashboard
│   ├── src/
│   └── Dockerfile
├── docker/
│   └── docker-compose.yml
├── scripts/
│   ├── install.sh
│   ├── normalize_clips.sh
│   ├── status.sh
│   └── watchdog.sh
└── systemd/
    ├── ffplayout-watchdog.service
    └── ffplayout-watchdog.timer
```

---

## Managing the Stack

```bash
# Check status
bash scripts/status.sh

# View logs
docker logs -f veka-backend
docker logs -f mediamtx

# Restart everything
cd /opt/247live/docker && docker compose restart

# Stop
cd /opt/247live/docker && docker compose down

# Update images
cd /opt/247live/docker && docker compose pull && docker compose build && docker compose up -d
```

---

## Normalizing Clips

```bash
mkdir -p /srv/clips/raw
# move raw clips into /srv/clips/raw, then:
bash scripts/normalize_clips.sh
# normalized files appear as *_norm.mp4
```
