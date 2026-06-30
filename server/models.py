import uuid
from datetime import datetime
from sqlalchemy import (
    Column, String, Text, Boolean, Integer, BigInteger,
    DateTime, ForeignKey, JSON, UniqueConstraint, Index,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from database import Base


class Channel(Base):
    __tablename__ = "channels"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(128), nullable=False)
    slug = Column(String(128), unique=True, nullable=False)
    description = Column(Text)
    category = Column(String(64))
    is_live = Column(Boolean, nullable=False, default=False)
    status = Column(String(20), nullable=False, default="stopped")
    process_pid = Column(Integer)
    clip_folder = Column(Text, nullable=False)
    rtmp_path = Column(String(128), nullable=False)
    stream_key_token = Column(Text)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    platforms = relationship("Platform", back_populates="channel", cascade="all, delete-orphan")
    clips = relationship("Clip", back_populates="channel", cascade="all, delete-orphan")
    alerts = relationship("ChannelAlert", back_populates="channel", cascade="all, delete-orphan")
    sessions = relationship("StreamSession", back_populates="channel", cascade="all, delete-orphan")


class Platform(Base):
    __tablename__ = "platforms"
    __table_args__ = (
        UniqueConstraint("channel_id", "platform_type", name="uq_channel_platform"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    channel_id = Column(UUID(as_uuid=True), ForeignKey("channels.id", ondelete="CASCADE"), nullable=False)
    platform_type = Column(String(32), nullable=False)
    name = Column(String(128))
    rtmp_url = Column(Text, nullable=False)
    stream_key_enc = Column(Text)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    channel = relationship("Channel", back_populates="platforms")


class Clip(Base):
    __tablename__ = "clips"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    channel_id = Column(UUID(as_uuid=True), ForeignKey("channels.id", ondelete="CASCADE"), nullable=False)
    filename = Column(String(255), nullable=False)
    filepath = Column(Text, nullable=False)
    duration_ms = Column(Integer)
    file_size_bytes = Column(BigInteger)
    status = Column(String(20), nullable=False, default="ready")
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    channel = relationship("Channel", back_populates="clips")

    __table_args__ = (
        Index("idx_clips_channel", "channel_id"),
        Index("idx_clips_status", "status"),
    )


class AlertTemplate(Base):
    __tablename__ = "alert_templates"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(128), nullable=False)
    type = Column(String(32), nullable=False)
    layout = Column(JSON, nullable=False, default=dict)
    content = Column(JSON, nullable=False, default=dict)
    is_default = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)


class ChannelAlert(Base):
    __tablename__ = "channel_alerts"
    __table_args__ = (
        UniqueConstraint("channel_id", "type", name="uq_channel_alert_type"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    channel_id = Column(UUID(as_uuid=True), ForeignKey("channels.id", ondelete="CASCADE"), nullable=False)
    template_id = Column(UUID(as_uuid=True), ForeignKey("alert_templates.id", ondelete="SET NULL"))
    type = Column(String(32), nullable=False)
    is_enabled = Column(Boolean, nullable=False, default=True)
    config = Column(JSON, nullable=False, default=dict)
    cooldown_ms = Column(Integer, default=5000)
    webhook_secret = Column(Text)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    channel = relationship("Channel", back_populates="alerts")
    template = relationship("AlertTemplate")


class StreamSession(Base):
    __tablename__ = "stream_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    channel_id = Column(UUID(as_uuid=True), ForeignKey("channels.id", ondelete="CASCADE"), nullable=False)
    started_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    ended_at = Column(DateTime(timezone=True))
    duration_ms = Column(BigInteger)
    peak_viewers = Column(Integer, default=0)
    total_views = Column(BigInteger, default=0)
    title = Column(String(255))
    metadata = Column(JSON, default=dict)

    channel = relationship("Channel", back_populates="sessions")


class WebhookLog(Base):
    __tablename__ = "webhook_logs"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    channel_id = Column(UUID(as_uuid=True), ForeignKey("channels.id", ondelete="CASCADE"), nullable=False)
    provider = Column(String(32), nullable=False)
    event_type = Column(String(64))
    payload = Column(JSON, nullable=False)
    processed = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
