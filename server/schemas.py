from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field
from uuid import UUID


# ── Channel ──────────────────────────────────────────────────────────────────
class ChannelBase(BaseModel):
    name: str
    slug: str
    description: Optional[str] = None
    category: Optional[str] = None
    clip_folder: str
    rtmp_path: str


class ChannelCreate(ChannelBase):
    pass


class ChannelUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    clip_folder: Optional[str] = None
    rtmp_path: Optional[str] = None


class ChannelResponse(ChannelBase):
    id: UUID
    is_live: bool
    status: str
    process_pid: Optional[int] = None
    stream_key_token: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ChannelWithPlatforms(ChannelResponse):
    platforms: list["PlatformResponse"] = []


class ChannelDetail(ChannelWithPlatforms):
    clip_count: int = 0
    hls_url: Optional[str] = None


# ── Platform ─────────────────────────────────────────────────────────────────
class PlatformBase(BaseModel):
    platform_type: str
    name: Optional[str] = None
    rtmp_url: str


class PlatformCreate(PlatformBase):
    stream_key: str


class PlatformUpdate(BaseModel):
    name: Optional[str] = None
    rtmp_url: Optional[str] = None
    stream_key: Optional[str] = None
    is_active: Optional[bool] = None


class PlatformResponse(PlatformBase):
    id: UUID
    channel_id: UUID
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ── Clip ─────────────────────────────────────────────────────────────────────
class ClipResponse(BaseModel):
    id: UUID
    channel_id: UUID
    filename: str
    filepath: str
    duration_ms: Optional[int] = None
    file_size_bytes: Optional[int] = None
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


# ── Alert ────────────────────────────────────────────────────────────────────
class AlertConfigBase(BaseModel):
    type: str
    is_enabled: bool = True
    config: dict = {}
    cooldown_ms: int = 5000


class AlertConfigCreate(AlertConfigBase):
    template_id: Optional[UUID] = None


class AlertConfigUpdate(BaseModel):
    is_enabled: Optional[bool] = None
    config: Optional[dict] = None
    cooldown_ms: Optional[int] = None
    template_id: Optional[UUID] = None


class AlertConfigResponse(AlertConfigBase):
    id: UUID
    channel_id: UUID
    template_id: Optional[UUID] = None
    webhook_secret: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class AlertTemplateResponse(BaseModel):
    id: UUID
    name: str
    type: str
    layout: dict
    content: dict
    is_default: bool

    class Config:
        from_attributes = True


# ── Alert Event (webhook payload) ───────────────────────────────────────────
class AlertEvent(BaseModel):
    type: str
    name: str = ""
    amount: float = 0.0
    message: str = ""
    duration: int = 10
    image: str = ""
    sound: str = ""


# ── Stream Session ───────────────────────────────────────────────────────────
class StreamSessionResponse(BaseModel):
    id: UUID
    channel_id: UUID
    started_at: datetime
    ended_at: Optional[datetime] = None
    duration_ms: Optional[int] = None
    peak_viewers: int = 0
    total_views: int = 0
    title: Optional[str] = None

    class Config:
        from_attributes = True


# ── IRL ──────────────────────────────────────────────────────────────────────
class IRLStatus(BaseModel):
    is_live: bool
    stream_info: Optional[dict] = None
    overlay_active: bool = False


class IRLStartRequest(BaseModel):
    channel_id: UUID
    platforms: list[PlatformCreate] = []


# ── Generic ──────────────────────────────────────────────────────────────────
class MessageResponse(BaseModel):
    message: str
    success: bool = True


class ErrorResponse(BaseModel):
    detail: str
    success: bool = False
