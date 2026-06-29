from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse
from config import settings

router = APIRouter()


@router.get("/{channel_slug}/stream.m3u8")
async def proxy_hls(channel_slug: str):
    url = f"{settings.hls_base_url}/{channel_slug}/stream.m3u8"
    return RedirectResponse(url=url)


@router.get("/{channel_slug}/stream.ts")
async def proxy_hls_segment(channel_slug: str):
    url = f"{settings.hls_base_url}/{channel_slug}/stream.ts"
    return RedirectResponse(url=url)
