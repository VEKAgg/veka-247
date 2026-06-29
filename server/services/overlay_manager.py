import asyncio
import subprocess
from pathlib import Path
from models import Channel

_overlay_processes: dict[str, asyncio.subprocess.Process] = {}


async def start_overlay(channel: Channel):
    if channel.slug in _overlay_processes:
        proc = _overlay_processes[channel.slug]
        if proc.returncode is None:
            return

    overlay_dir = Path(f"/overlays/channel-{channel.slug}")
    overlay_dir.mkdir(parents=True, exist_ok=True)

    alert_html = overlay_dir / "alert.html"
    if not alert_html.exists():
        _create_default_overlay(alert_html)

    cmd = [
        "ffmpeg",
        "-f", "image2pipe",
        "-framerate", "10",
        "-i", "pipe:0",
        "-f", "rawvideo",
        "-pix_fmt", "rgba",
        "pipe:1",
    ]

    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    _overlay_processes[channel.slug] = proc
    asyncio.create_task(_capture_frames(channel.slug))


async def stop_overlay(channel: Channel):
    proc = _overlay_processes.pop(channel.slug, None)
    if proc and proc.returncode is None:
        proc.terminate()
        try:
            await asyncio.wait_for(proc.wait(), timeout=5)
        except asyncio.TimeoutError:
            proc.kill()


async def _capture_frames(slug: str):
    proc = _overlay_processes.get(slug)
    if not proc or not proc.stdin:
        return

    try:
        from playwright.async_api import async_playwright
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            page = await browser.new_page(viewport={"width": 1280, "height": 720})
            alert_path = Path(f"/overlays/channel-{slug}/alert.html")
            await page.goto(f"file://{alert_path}")

            while slug in _overlay_processes:
                screenshot = await page.screenshot(type="png")
                if proc.stdin and not proc.stdin.is_closing():
                    proc.stdin.write(screenshot)
                    await proc.stdin.drain()
                await asyncio.sleep(0.1)

            await browser.close()
    except ImportError:
        pass
    except Exception:
        pass


def _create_default_overlay(path: Path):
    html = """<!DOCTYPE html>
<html>
<head>
<style>
body { background: transparent; margin: 0; overflow: hidden; }
.alert {
  position: fixed;
  bottom: 80px;
  left: 50%;
  transform: translateX(-50%);
  opacity: 0;
  padding: 20px 40px;
  background: rgba(0,0,0,0.85);
  border: 2px solid #FFD700;
  border-radius: 16px;
}
.alert.active {
  animation: slideUp 0.5s ease-out forwards, fadeOut 0.5s ease-in 9s forwards;
}
.alert-name { font-size: 36px; font-weight: bold; color: #FFD700; }
.alert-message { font-size: 24px; color: #fff; margin-top: 4px; }
@keyframes slideUp {
  from { transform: translateX(-50%) translateY(100px); opacity: 0; }
  to { transform: translateX(-50%) translateY(0); opacity: 1; }
}
@keyframes fadeOut { to { opacity: 0; } }
</style>
</head>
<body>
<div id="alert" class="alert">
  <div class="alert-name" id="alert-name"></div>
  <div class="alert-message" id="alert-message"></div>
</div>
<script>
const ws = new WebSocket('ws://backend:8000/ws/overlay/CHANNEL_SLUG');
ws.onmessage = (e) => {
  const d = JSON.parse(e.data);
  document.getElementById('alert-name').textContent = d.name;
  document.getElementById('alert-message').textContent = d.message;
  const a = document.getElementById('alert');
  a.classList.add('active');
  setTimeout(() => a.classList.remove('active'), d.duration * 1000);
};
</script>
</body>
</html>"""
    path.write_text(html.replace("CHANNEL_SLUG", path.parent.name.replace("channel-", "")))
