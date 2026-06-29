import asyncio
import subprocess
import signal
from pathlib import Path
from models import Channel


async def start_ffplayout(channel: Channel) -> int:
    config_path = f"/etc/ffplayout/ffplayout.yml"
    cmd = [
        "ffplayout",
        "-c", config_path,
        "--ui-port", "8787",
    ]
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    if proc.pid:
        pid_file = Path(f"/tmp/ffplayout-{channel.slug}.pid")
        pid_file.write_text(str(proc.pid))
    return proc.pid


async def stop_ffplayout(channel: Channel):
    pid_file = Path(f"/tmp/ffplayout-{channel.slug}.pid")
    if pid_file.exists():
        pid = int(pid_file.read_text().strip())
        try:
            import os
            os.kill(pid, signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            pass
        pid_file.unlink(missing_ok=True)

    import os
    for proc_name in ["ffplayout", f"ffplayout-{channel.slug}"]:
        result = await asyncio.create_subprocess_exec(
            "pkill", "-f", proc_name,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await result.wait()


async def get_process_status(channel: Channel) -> dict:
    pid_file = Path(f"/tmp/ffplayout-{channel.slug}.pid")
    is_running = False
    pid = None

    if pid_file.exists():
        pid = int(pid_file.read_text().strip())
        try:
            import os
            os.kill(pid, 0)
            is_running = True
        except (ProcessLookupError, PermissionError):
            is_running = False

    return {
        "channel_id": str(channel.id),
        "slug": channel.slug,
        "status": channel.status,
        "pid": pid,
        "is_running": is_running,
    }
