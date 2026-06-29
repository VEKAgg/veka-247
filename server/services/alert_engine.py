import json
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

    overlay_html = _generate_overlay_html(alert_data)
    (overlay_dir / "alert.html").write_text(overlay_html)

    overlay_css = _generate_overlay_css(event.type)
    (overlay_dir / "alert.css").write_text(overlay_css)

    import asyncio
    asyncio.get_event_loop().call_later(
        event.duration,
        lambda: _clear_alert(overlay_dir),
    )


def _clear_alert(overlay_dir: Path):
    alert_file = overlay_dir / "current_alert.json"
    if alert_file.exists():
        alert_file.write_text(json.dumps({"type": None, "name": "", "message": ""}))


def _generate_overlay_html(data: dict) -> str:
    message = data.get("message", "")
    name = data.get("name", "")
    amount = data.get("amount", 0)

    if data["type"] == "donation":
        display = f"{name} donated ${amount:.2f}!"
    elif data["type"] == "follow":
        display = f"{name} is now following!"
    elif data["type"] == "subscription":
        display = f"{name} subscribed!"
    elif data["type"] == "raid":
        display = f"{name} raided with {amount} viewers!"
    else:
        display = message or f"{name} triggered an alert!"

    return f"""<!DOCTYPE html>
<html>
<head>
<link rel="stylesheet" href="alert.css">
</head>
<body>
<div id="alert" class="alert alert-{data['type']}">
  <div class="alert-icon">
    <img src="assets/{data['type']}.png" onerror="this.style.display='none'">
  </div>
  <div class="alert-content">
    <div class="alert-name">{name}</div>
    <div class="alert-message">{display}</div>
  </div>
</div>
</body>
</html>"""


def _generate_overlay_css(alert_type: str) -> str:
    colors = {
        "donation": "#FFD700",
        "follow": "#9146FF",
        "subscription": "#00AD03",
        "raid": "#FF4500",
        "cheer": "#FF6B00",
    }
    color = colors.get(alert_type, "#FFFFFF")

    return f"""* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{ background: transparent; overflow: hidden; font-family: 'Segoe UI', Arial, sans-serif; }}

.alert {{
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
  border: 2px solid {color};
  border-radius: 16px;
  box-shadow: 0 0 30px {color}40, 0 8px 32px rgba(0,0,0,0.6);
  animation: slideUp 0.5s ease-out 0.1s forwards, fadeOut 0.5s ease-in 9s forwards;
}}

.alert-icon img {{
  width: 80px;
  height: 80px;
}}

.alert-content {{
  text-align: left;
}}

.alert-name {{
  font-size: 36px;
  font-weight: bold;
  color: {color};
  text-shadow: 0 2px 4px rgba(0,0,0,0.5);
}}

.alert-message {{
  font-size: 24px;
  color: #ffffff;
  margin-top: 4px;
}}

@keyframes slideUp {{
  from {{ transform: translateX(-50%) translateY(100px); opacity: 0; }}
  to {{ transform: translateX(-50%) translateY(0); opacity: 1; }}
}}

@keyframes fadeOut {{
  to {{ opacity: 0; }}
}}"""
