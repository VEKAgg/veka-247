from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from database import get_db
from models import Channel, Platform
from schemas import (
    ChannelCreate, ChannelUpdate, ChannelResponse,
    ChannelWithPlatforms, ChannelDetail, MessageResponse,
)
from services.clip_scanner import count_clips

router = APIRouter()


@router.get("/", response_model=list[ChannelWithPlatforms])
async def list_channels(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Channel).order_by(Channel.created_at))
    channels = result.scalars().all()
    out = []
    for ch in channels:
        await db.refresh(ch, ["platforms"])
        out.append(ch)
    return out


@router.get("/{channel_id}", response_model=ChannelDetail)
async def get_channel(channel_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Channel).where(Channel.id == channel_id))
    ch = result.scalar_one_or_none()
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")
    await db.refresh(ch, ["platforms"])
    clip_count = await count_clips(ch.clip_folder)
    return ChannelDetail(
        **{k: v for k, v in ch.__dict__.items() if k != "_sa_instance_state"},
        clip_count=clip_count,
        hls_url=f"{settings.hls_base_url}/{ch.rtmp_path}/stream.m3u8",
    )


@router.post("/", response_model=ChannelResponse, status_code=201)
async def create_channel(data: ChannelCreate, db: AsyncSession = Depends(get_db)):
    existing = await db.execute(select(Channel).where(Channel.slug == data.slug))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Channel slug already exists")
    ch = Channel(**data.model_dump())
    db.add(ch)
    await db.flush()
    await db.refresh(ch)
    return ch


@router.patch("/{channel_id}", response_model=ChannelResponse)
async def update_channel(channel_id: UUID, data: ChannelUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Channel).where(Channel.id == channel_id))
    ch = result.scalar_one_or_none()
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")
    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(ch, key, value)
    await db.flush()
    await db.refresh(ch)
    return ch


@router.delete("/{channel_id}", response_model=MessageResponse)
async def delete_channel(channel_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Channel).where(Channel.id == channel_id))
    ch = result.scalar_one_or_none()
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")
    await db.delete(ch)
    return MessageResponse(message=f"Channel '{ch.slug}' deleted")


@router.post("/{channel_id}/start", response_model=MessageResponse)
async def start_channel(channel_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Channel).where(Channel.id == channel_id))
    ch = result.scalar_one_or_none()
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")
    from services.ffmpeg_manager import start_ffplayout
    pid = await start_ffplayout(ch)
    ch.status = "running"
    ch.process_pid = pid
    await db.flush()
    return MessageResponse(message=f"Channel '{ch.slug}' started (PID: {pid})")


@router.post("/{channel_id}/stop", response_model=MessageResponse)
async def stop_channel(channel_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Channel).where(Channel.id == channel_id))
    ch = result.scalar_one_or_none()
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")
    from services.ffmpeg_manager import stop_ffplayout
    await stop_ffplayout(ch)
    ch.status = "stopped"
    ch.process_pid = None
    await db.flush()
    return MessageResponse(message=f"Channel '{ch.slug}' stopped")


@router.get("/{channel_id}/status")
async def channel_status(channel_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Channel).where(Channel.id == channel_id))
    ch = result.scalar_one_or_none()
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")
    from services.ffmpeg_manager import get_process_status
    status = await get_process_status(ch)
    return status
