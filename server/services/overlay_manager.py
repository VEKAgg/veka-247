import asyncio
from pathlib import Path
from models import Channel
from services.alert_engine import _ensure_overlay_template

_overlay_processes: dict[str, asyncio.subprocess.Process] = {}


async def start_overlay(channel: Channel):
    if channel.slug in _overlay_processes:
        proc = _overlay_processes[channel.slug]
        if proc.returncode is None:
            return

    overlay_dir = Path(f"/overlays/channel-{channel.slug}")
    overlay_dir.mkdir(parents=True, exist_ok=True)
    _ensure_overlay_template(overlay_dir, channel.slug)

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
