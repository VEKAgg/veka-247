import json
import asyncio
from pathlib import Path
from models import Channel
from schemas import AlertEvent


async def dispatch_alert(channel: Channel, event: AlertEvent):
    overlay_dir = Path(f"/overlays/channel-{channel.slug}")
    overlay_dir.mkdir(parents=True, exist_ok=True)

    alert_data = {
        "type": event.type,
        "name": event.name,
        "amount": event.amount,
        "message": event.message,
        "duration": event.duration,
        "image": event.image,
        "sound": event.sound,
    }

    alert_file = overlay_dir / "current_alert.json"
    alert_file.write_text(json.dumps(alert_data))

    _ensure_overlay_template(overlay_dir, channel.slug)

    loop = asyncio.get_running_loop()
    loop.call_later(
        event.duration,
        lambda: _clear_alert(overlay_dir),
    )


def _clear_alert(overlay_dir: Path):
    alert_file = overlay_dir / "current_alert.json"
    if alert_file.exists():
        alert_file.write_text(json.dumps({"type": None, "name": "", "message": ""}))


def _ensure_overlay_template(overlay_dir: Path, slug: str):
    html_file = overlay_dir / "alert.html"
    if html_file.exists():
        return

    html_file.write_text(_OVERLAY_HTML_TEMPLATE.replace("CHANNEL_SLUG", slug))
    (overlay_dir / "alert.css").write_text(_OVERLAY_CSS_TEMPLATE)


_ALERT_COLORS = {
    "donation": "#FFD700",
    "follow": "#9146FF",
    "subscription": "#00AD03",
    "raid": "#FF4500",
    "cheer": "#FF6B00",
}

_OVERLAY_CSS_TEMPLATE = """\
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: transparent; overflow: hidden; font-family: 'Segoe UI', Arial, sans-serif; }

.alert {
  position: fixed;
  bottom: 80px;
  left: 50%;
  transform: translateX(-50%) translateY(100px);
  opacity: 0;
  display: flex;
  align-items: center;
  gap: 20px;
  padding: 20px 40px;
  background: rgba(0, 0, 0, 0.85);
  border: 2px solid #FFD700;
  border-radius: 16px;
  box-shadow: 0 0 30px rgba(255,215,0,0.25), 0 8px 32px rgba(0,0,0,0.6);
}

.alert.active {
  animation: slideUp 0.5s ease-out forwards;
}

.alert.fade-out {
  animation: fadeOut 0.5s ease-in forwards;
}

.alert-icon img {
  width: 80px;
  height: 80px;
}

.alert-content { text-align: left; }

.alert-name {
  font-size: 36px;
  font-weight: bold;
  color: #FFD700;
  text-shadow: 0 2px 4px rgba(0,0,0,0.5);
}

.alert-message {
  font-size: 24px;
  color: #ffffff;
  margin-top: 4px;
}

@keyframes slideUp {
  from { transform: translateX(-50%) translateY(100px); opacity: 0; }
  to { transform: translateX(-50%) translateY(0); opacity: 1; }
}

@keyframes fadeOut {
  to { opacity: 0; }
}"""

_OVERLAY_HTML_TEMPLATE = """\
<!DOCTYPE html>
<html>
<head>
<link rel="stylesheet" href="alert.css">
</head>
<body>
<div id="alert" class="alert">
  <div class="alert-icon">
    <img id="alert-icon-img" src="" onerror="this.style.display='none'">
  </div>
  <div class="alert-content">
    <div class="alert-name" id="alert-name"></div>
    <div class="alert-message" id="alert-message"></div>
  </div>
</div>
<script>
const COLORS = {
  donation: '#FFD700',
  follow: '#9146FF',
  subscription: '#00AD03',
  raid: '#FF4500',
  cheer: '#FF6B00',
};

let fadeTimeout = null;

function showAlert(d) {
  const el = document.getElementById('alert');
  const nameEl = document.getElementById('alert-name');
  const msgEl = document.getElementById('alert-message');
  const iconImg = document.getElementById('alert-icon-img');

  const color = COLORS[d.type] || '#FFFFFF';
  el.style.borderColor = color;
  el.style.boxShadow = '0 0 30px ' + color + '40, 0 8px 32px rgba(0,0,0,0.6)';
  nameEl.style.color = color;

  nameEl.textContent = d.name || '';
  msgEl.textContent = d.message || '';

  if (d.image) {
    iconImg.src = d.image;
    iconImg.style.display = '';
  } else {
    iconImg.style.display = 'none';
  }

  el.classList.remove('fade-out');
  el.classList.add('active');

  if (fadeTimeout) clearTimeout(fadeTimeout);
  fadeTimeout = setTimeout(() => {
    el.classList.remove('active');
    el.classList.add('fade-out');
  }, Math.max((d.duration || 10) - 1, 0) * 1000);
}

const ws = new WebSocket('ws://' + location.hostname + ':8000/ws/overlay/CHANNEL_SLUG');
ws.onmessage = (e) => {
  const d = JSON.parse(e.data);
  if (d.type) showAlert(d);
};
ws.onerror = () => setTimeout(() => location.reload(), 5000);
</script>
</body>
</html>"""
