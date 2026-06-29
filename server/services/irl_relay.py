import asyncio
import json
from pathlib import Path
from models import Channel

_irl_process: asyncio.subprocess.Process | None = None
_overlay_process: asyncio.subprocess.Process | None = None


async def get_irl_status() -> dict:
    global _irl_process
    is_live = False
    stream_info = None

    try:
        import httpx
        async with httpx.AsyncClient() as client:
            resp = await client.get("http://mediamtx:9997/v3/paths/list")
            if resp.status_code == 200:
                paths = resp.json().get("items", [])
                for p in paths:
                    if p.get("name") == "live/irl" and p.get("readers", 0) > 0:
                        is_live = True
                        stream_info = {
                            "name": p.get("name"),
                            "ready": p.get("ready"),
                            "readers": p.get("readers", 0),
                        }
                        break
    except Exception:
        pass

    return {
        "is_live": is_live,
        "stream_info": stream_info,
        "overlay_active": _overlay_process is not None and _overlay_process.returncode is None,
    }


async def start_irl_relay(channel: Channel = None):
    global _irl_process, _overlay_process

    if _irl_process and _irl_process.returncode is None:
        return

    cmd = [
        "ffmpeg", "-re",
        "-i", "rtsp://localhost:8554/live/irl",
        "-vf", "scale=1280:720:force_original_aspect_ratio=decrease,pad=1280:720:(ow-iw)/2:(oh-ih)/2:color=black,fps=30,format=yuv420p",
        "-c:v", "libx264", "-preset", "superfast", "-b:v", "2500k",
        "-c:a", "aac", "-b:a", "128k",
        "-f", "flv",
        "rtmp://localhost:1937/live/irl-relay",
    ]

    _irl_process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )

    asyncio.create_task(_monitor_irl())


async def stop_irl_relay():
    global _irl_process, _overlay_process

    if _irl_process and _irl_process.returncode is None:
        _irl_process.terminate()
        try:
            await asyncio.wait_for(_irl_process.wait(), timeout=5)
        except asyncio.TimeoutError:
            _irl_process.kill()
    _irl_process = None

    if _overlay_process and _overlay_process.returncode is None:
        _overlay_process.terminate()
        try:
            await asyncio.wait_for(_overlay_process.wait(), timeout=5)
        except asyncio.TimeoutError:
            _overlay_process.kill()
    _overlay_process = None


async def _monitor_irl():
    global _irl_process
    if _irl_process:
        await _irl_process.wait()
        if _irl_process.returncode != 0:
            await asyncio.sleep(5)
            await start_irl_relay()
