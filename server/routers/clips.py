import shutil
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from database import get_db
from models import Channel, Clip
from schemas import ClipResponse, MessageResponse
from services.clip_scanner import VIDEO_EXTENSIONS, scan_folder, regenerate_concat_list

router = APIRouter()


@router.get("/{channel_id}/clips", response_model=list[ClipResponse])
async def list_clips(channel_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Clip).where(Clip.channel_id == channel_id).order_by(Clip.created_at.desc())
    )
    return result.scalars().all()


@router.post("/{channel_id}/clips/upload", response_model=list[ClipResponse], status_code=201)
async def upload_clips(channel_id: UUID, files: list[UploadFile] = File(...), db: AsyncSession = Depends(get_db)):
    ch = await db.get(Channel, channel_id)
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")

    clip_dir = Path(ch.clip_folder)
    clip_dir.mkdir(parents=True, exist_ok=True)

    created = []
    for file in files:
        ext = Path(file.filename).suffix.lower()
        if ext not in VIDEO_EXTENSIONS:
            continue

        dest = clip_dir / file.filename
        file_size = 0
        with open(dest, "wb") as f:
            while chunk := await file.read(1024 * 1024):
                f.write(chunk)
                file_size += len(chunk)

        clip = Clip(
            channel_id=channel_id,
            filename=file.filename,
            filepath=str(dest),
            file_size_bytes=file_size,
            status="ready",
        )
        db.add(clip)
        created.append(clip)

    await db.flush()
    for clip in created:
        await db.refresh(clip)

    await regenerate_concat_list(ch)

    return created


@router.delete("/{channel_id}/clips/{clip_id}", response_model=MessageResponse)
async def delete_clip(channel_id: UUID, clip_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Clip).where(Clip.id == clip_id, Clip.channel_id == channel_id)
    )
    clip = result.scalar_one_or_none()
    if not clip:
        raise HTTPException(status_code=404, detail="Clip not found")

    filepath = Path(clip.filepath)
    if filepath.exists():
        filepath.unlink()

    await db.delete(clip)
    await db.flush()

    ch = await db.get(Channel, channel_id)
    if ch:
        await regenerate_concat_list(ch)

    return MessageResponse(message=f"Clip '{clip.filename}' deleted")


@router.post("/{channel_id}/clips/scan", response_model=MessageResponse)
async def scan_clips(channel_id: UUID, db: AsyncSession = Depends(get_db)):
    ch = await db.get(Channel, channel_id)
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")

    new_clips = await scan_folder(ch, db)
    await regenerate_concat_list(ch)

    return MessageResponse(message=f"Scanned {new_clips} new clips")
