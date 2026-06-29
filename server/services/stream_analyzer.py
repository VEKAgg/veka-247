import httpx
from config import settings


async def get_stream_info(path: str) -> dict | None:
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{settings.mediamtx_url}/v3/paths/get/{path}")
            if resp.status_code == 200:
                return resp.json()
    except Exception:
        pass
    return None


async def detect_resolution(path: str) -> dict:
    info = await get_stream_info(path)
    if not info:
        return {"width": 1280, "height": 720, "fps": 30, "bitrate": 2500}

    return {
        "width": 1280,
        "height": 720,
        "fps": 30,
        "bitrate": 2500,
    }


async def list_active_streams() -> list[dict]:
    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(f"{settings.mediamtx_url}/v3/paths/list")
            if resp.status_code == 200:
                items = resp.json().get("items", [])
                return [
                    {
                        "name": p.get("name"),
                        "ready": p.get("ready"),
                        "readers": p.get("readers", 0),
                    }
                    for p in items
                    if p.get("readers", 0) > 0
                ]
    except Exception:
        pass
    return []
