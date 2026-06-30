from pathlib import Path
from models import Channel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from models import Clip

VIDEO_EXTENSIONS = {".mp4", ".mkv", ".mov", ".avi", ".flv", ".ts"}


async def count_clips(clip_folder: str) -> int:
    clip_dir = Path(clip_folder)
    if not clip_dir.exists():
        return 0
    return sum(
        1 for f in clip_dir.iterdir()
        if f.is_file() and f.suffix.lower() in VIDEO_EXTENSIONS
    )


async def scan_folder(channel: Channel, db: AsyncSession) -> int:
    clip_dir = Path(channel.clip_folder)
    if not clip_dir.exists():
        clip_dir.mkdir(parents=True, exist_ok=True)
        return 0

    existing = await db.execute(
        select(Clip.filepath).where(Clip.channel_id == channel.id)
    )
    existing_paths = {row[0] for row in existing.all()}

    new_count = 0
    for f in clip_dir.iterdir():
        if f.is_file() and f.suffix.lower() in VIDEO_EXTENSIONS:
            if str(f) not in existing_paths:
                clip = Clip(
                    channel_id=channel.id,
                    filename=f.name,
                    filepath=str(f),
                    file_size_bytes=f.stat().st_size,
                    status="ready",
                )
                db.add(clip)
                new_count += 1

    await db.flush()
    return new_count


async def regenerate_concat_list(channel: Channel):
    clip_dir = Path(channel.clip_folder)
    concat_file = clip_dir / "clips.txt"

    clips = sorted(
        [f for f in clip_dir.iterdir() if f.is_file() and f.suffix.lower() in VIDEO_EXTENSIONS],
        key=lambda x: x.name,
    )

    if not clips:
        concat_file.write_text("# No clips available\n")
        return

    lines = ["ffconcat version 1.0"]
    for clip in clips:
        lines.append(f"file '{clip.name}'")

    if len(clips) > 1:
        lines.append(f"file '{clips[0].name}'")

    concat_file.write_text("\n".join(lines) + "\n")
