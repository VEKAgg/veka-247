from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID
from database import get_db
from models import Channel
from schemas import IRLStatus, MessageResponse
from services.irl_relay import get_irl_status, start_irl_relay, stop_irl_relay

router = APIRouter()


@router.get("/status", response_model=IRLStatus)
async def irl_status():
    return await get_irl_status()


@router.post("/start", response_model=MessageResponse)
async def start_irl(channel_id: UUID = None, db: AsyncSession = Depends(get_db)):
    if channel_id:
        ch = await db.get(Channel, channel_id)
        if not ch:
            raise HTTPException(status_code=404, detail="Channel not found")
        await start_irl_relay(ch)
        return MessageResponse(message=f"IRL relay started for channel '{ch.slug}'")
    else:
        await start_irl_relay()
        return MessageResponse(message="IRL relay started")


@router.post("/stop", response_model=MessageResponse)
async def stop_irl():
    await stop_irl_relay()
    return MessageResponse(message="IRL relay stopped")
