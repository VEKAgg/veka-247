from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID
from database import get_db, AsyncSessionLocal
from models import Channel, ChannelAlert, WebhookLog, AlertTemplate
from schemas import (
    AlertConfigCreate, AlertConfigUpdate, AlertConfigResponse,
    AlertEvent, MessageResponse,
)
from services.alert_engine import dispatch_alert

router = APIRouter()


@router.get("/templates")
async def list_templates():
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(AlertTemplate).order_by(AlertTemplate.name))
        return [
            {
                "id": str(t.id),
                "name": t.name,
                "type": t.type,
                "layout": t.layout,
                "content": t.content,
                "is_default": t.is_default,
            }
            for t in result.scalars().all()
        ]


@router.get("/{channel_id}/config", response_model=list[AlertConfigResponse])
async def list_alert_configs(channel_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(ChannelAlert).where(ChannelAlert.channel_id == channel_id)
    )
    return result.scalars().all()


@router.post("/{channel_id}/config", response_model=AlertConfigResponse, status_code=201)
async def create_alert_config(channel_id: UUID, data: AlertConfigCreate, db: AsyncSession = Depends(get_db)):
    ch = await db.get(Channel, channel_id)
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")

    existing = await db.execute(
        select(ChannelAlert).where(
            ChannelAlert.channel_id == channel_id,
            ChannelAlert.type == data.type,
        )
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail=f"Alert type '{data.type}' already configured")

    alert = ChannelAlert(channel_id=channel_id, **data.model_dump())
    db.add(alert)
    await db.flush()
    await db.refresh(alert)
    return alert


@router.patch("/{channel_id}/config/{alert_id}", response_model=AlertConfigResponse)
async def update_alert_config(
    channel_id: UUID, alert_id: UUID, data: AlertConfigUpdate, db: AsyncSession = Depends(get_db)
):
    result = await db.execute(
        select(ChannelAlert).where(ChannelAlert.id == alert_id, ChannelAlert.channel_id == channel_id)
    )
    alert = result.scalar_one_or_none()
    if not alert:
        raise HTTPException(status_code=404, detail="Alert config not found")

    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(alert, key, value)

    await db.flush()
    await db.refresh(alert)
    return alert


@router.post("/{channel_id}/webhook/streamlabs")
async def streamlabs_webhook(channel_id: UUID, request: Request, db: AsyncSession = Depends(get_db)):
    return await _process_webhook(channel_id, "streamlabs", request, db)


@router.post("/{channel_id}/webhook/streamelements")
async def streamelements_webhook(channel_id: UUID, request: Request, db: AsyncSession = Depends(get_db)):
    return await _process_webhook(channel_id, "streamelements", request, db)


@router.post("/{channel_id}/test", response_model=MessageResponse)
async def test_alert(channel_id: UUID, event: AlertEvent, db: AsyncSession = Depends(get_db)):
    ch = await db.get(Channel, channel_id)
    if not ch:
        raise HTTPException(status_code=404, detail="Channel not found")

    await dispatch_alert(ch, event)
    return MessageResponse(message=f"Test alert dispatched to '{ch.slug}'")


async def _process_webhook(channel_id: UUID, provider: str, request: Request, db: AsyncSession):
    body = await request.json()

    log = WebhookLog(channel_id=channel_id, provider=provider, payload=body)
    db.add(log)

    ch = await db.get(Channel, channel_id)
    if not ch:
        log.processed = False
        await db.flush()
        return {"status": "error", "detail": "Channel not found"}

    event = _normalize_event(provider, body)
    if event:
        log.processed = True
        log.event_type = event.type
        await db.flush()

        await dispatch_alert(ch, event)
        return {"status": "ok"}
    else:
        log.processed = False
        await db.flush()
        return {"status": "ignored", "detail": "Unrecognized event type"}


def _normalize_event(provider: str, body: dict) -> AlertEvent | None:
    if provider == "streamlabs":
        msg = body.get("message", [{}])
        if isinstance(msg, list) and msg:
            msg = msg[0]
        return AlertEvent(
            type=body.get("type", "donation"),
            name=msg.get("name", ""),
            amount=msg.get("amount", 0),
            message=msg.get("message", ""),
        )
    elif provider == "streamelements":
        data = body.get("data", {})
        return AlertEvent(
            type=body.get("type", "donate"),
            name=data.get("name", ""),
            amount=data.get("amount", 0),
            message=data.get("message", ""),
        )
    return None
