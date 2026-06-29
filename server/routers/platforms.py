from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from database import get_db
from models import Channel, Platform
from schemas import PlatformCreate, PlatformUpdate, PlatformResponse, MessageResponse

router = APIRouter()


@router.get("/{channel_id}/platforms", response_model=list[PlatformResponse])
async def list_platforms(channel_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Platform).where(Platform.channel_id == channel_id).order_by(Platform.created_at)
    )
    return result.scalars().all()


@router.post("/{channel_id}/platforms", response_model=PlatformResponse, status_code=201)
async def create_platform(channel_id: UUID, data: PlatformCreate, db: AsyncSession = Depends(get_db)):
    ch = await db.get(Channel, channel_id)
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")

    existing = await db.execute(
        select(Platform).where(
            Platform.channel_id == channel_id,
            Platform.platform_type == data.platform_type,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail=f"Platform '{data.platform_type}' already exists for this channel")

    import hashlib
    key_hash = hashlib.sha256(data.stream_key.encode()).hexdigest()

    platform = Platform(
        channel_id=channel_id,
        platform_type=data.platform_type,
        name=data.name,
        rtmp_url=data.rtmp_url,
        stream_key_enc=key_hash,
    )
    db.add(platform)
    await db.flush()
    await db.refresh(platform)
    return platform


@router.patch("/{channel_id}/platforms/{platform_id}", response_model=PlatformResponse)
async def update_platform(
    channel_id: UUID, platform_id: UUID, data: PlatformUpdate, db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(Platform).where(Platform.id == platform_id, Platform.channel_id == channel_id)
    )
    platform = result.scalar_one_or_none()
    if not platform:
        raise HTTPException(status_code=404, detail="Platform not found")

    for key, value in data.model_dump(exclude_unset=True).items():
        if key == "stream_key" and value:
            import hashlib
            platform.stream_key_enc = hashlib.sha256(value.encode()).hexdigest()
        else:
            setattr(platform, key, value)

    await db.flush()
    await db.refresh(platform)
    return platform


@router.delete("/{channel_id}/platforms/{platform_id}", response_model=MessageResponse)
async def delete_platform(channel_id: UUID, platform_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Platform).where(Platform.id == platform_id, Platform.channel_id == channel_id)
    )
    platform = result.scalar_one_or_none()
    if not platform:
        raise HTTPException(status_code=404, detail="Platform not found")
    await db.delete(platform)
    return MessageResponse(message=f"Platform '{platform.platform_type}' deleted")
