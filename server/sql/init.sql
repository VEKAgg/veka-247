-- veka-247 PostgreSQL schema
-- Run via: docker exec -i veka-postgres psql -U veka -d veka < init.sql

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- USERS
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username        VARCHAR(64) NOT NULL UNIQUE,
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    display_name    VARCHAR(128),
    role            VARCHAR(20) NOT NULL DEFAULT 'admin'
                    CHECK (role IN ('admin', 'streamer', 'viewer')),
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Default admin user (password: admin — change immediately)
INSERT INTO users (username, email, password_hash, display_name, role)
VALUES ('admin', 'admin@veka.local', crypt('admin', gen_salt('bf')), 'Admin', 'admin')
ON CONFLICT (username) DO NOTHING;

-- ============================================================
-- CHANNELS
-- ============================================================
CREATE TABLE IF NOT EXISTS channels (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(128) NOT NULL,
    slug            VARCHAR(128) NOT NULL UNIQUE,
    description     TEXT,
    category        VARCHAR(64),
    is_live         BOOLEAN NOT NULL DEFAULT false,
    status          VARCHAR(20) NOT NULL DEFAULT 'stopped'
                    CHECK (status IN ('stopped', 'starting', 'running', 'error')),
    process_pid     INTEGER,
    clip_folder     TEXT NOT NULL,
    rtmp_path       VARCHAR(128) NOT NULL,
    stream_key_token TEXT DEFAULT encode(gen_random_bytes(16), 'hex'),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed the 4 channels
INSERT INTO channels (name, slug, description, category, clip_folder, rtmp_path) VALUES
    ('TTTR',      'tttr',      'GTA5 Roleplay Highlights',         'gta5',              '/srv/clips/tttr', 'live/tttr'),
    ('IGFV',      'igfv',      'Elite Dangerous Footage',           'elite_dangerous',   '/srv/clips/igfv', 'live/igfv'),
    ('FH6',       'fh6',       'Forza Horizon 6 Racing',            'forza',             '/srv/clips/fh6',  'live/fh6'),
    ('VA',        'va',        'Rocket League Past Content',        'rocket_league',     '/srv/clips/va',   'live/va')
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- PLATFORMS (per channel)
-- ============================================================
CREATE TABLE IF NOT EXISTS platforms (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    platform_type   VARCHAR(32) NOT NULL
                    CHECK (platform_type IN ('twitch', 'youtube', 'kick', 'facebook', 'custom_rtmp')),
    name            VARCHAR(128),
    rtmp_url        TEXT NOT NULL,
    stream_key_enc  TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(channel_id, platform_type)
);

-- ============================================================
-- CLIPS
-- ============================================================
CREATE TABLE IF NOT EXISTS clips (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    filename        VARCHAR(255) NOT NULL,
    filepath        TEXT NOT NULL,
    duration_ms     INTEGER,
    file_size_bytes BIGINT,
    status          VARCHAR(20) NOT NULL DEFAULT 'ready'
                    CHECK (status IN ('processing', 'ready', 'failed', 'archived')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_clips_channel ON clips(channel_id);
CREATE INDEX IF NOT EXISTS idx_clips_status ON clips(status);

-- ============================================================
-- ALERT TEMPLATES
-- ============================================================
CREATE TABLE IF NOT EXISTS alert_templates (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(128) NOT NULL,
    type            VARCHAR(32) NOT NULL
                    CHECK (type IN ('follow', 'subscription', 'donation', 'raid', 'host', 'cheer', 'custom')),
    layout          JSONB NOT NULL DEFAULT '{}',
    content         JSONB NOT NULL DEFAULT '{}',
    is_default      BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default templates
INSERT INTO alert_templates (name, type, layout, content, is_default) VALUES
    ('Default Donation', 'donation', '{"position": "bottom-center", "animation": "slideUp", "duration_ms": 10000}', '{"text": "{name} donated ${amount}!", "sound": "donation.mp3", "image": "donation.png"}', true),
    ('Default Follow', 'follow', '{"position": "bottom-center", "animation": "slideUp", "duration_ms": 5000}', '{"text": "{name} is now following!", "sound": "follow.mp3", "image": "follow.png"}', true),
    ('Default Subscribe', 'subscription', '{"position": "bottom-center", "animation": "slideUp", "duration_ms": 8000}', '{"text": "{name} subscribed!", "sound": "sub.mp3", "image": "sub.png"}', true),
    ('Default Raid', 'raid', '{"position": "bottom-center", "animation": "slideUp", "duration_ms": 8000}', '{"text": "{name} raided with {amount} viewers!", "sound": "raid.mp3", "image": "raid.png"}', true)
ON CONFLICT DO NOTHING;

-- ============================================================
-- CHANNEL ALERTS (per channel config)
-- ============================================================
CREATE TABLE IF NOT EXISTS channel_alerts (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    template_id     UUID REFERENCES alert_templates(id) ON DELETE SET NULL,
    type            VARCHAR(32) NOT NULL,
    is_enabled      BOOLEAN NOT NULL DEFAULT true,
    config          JSONB NOT NULL DEFAULT '{}',
    cooldown_ms     INTEGER DEFAULT 5000,
    webhook_secret  TEXT DEFAULT encode(gen_random_bytes(32), 'hex'),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(channel_id, type)
);

-- ============================================================
-- STREAM SESSIONS (history, partitioned by month)
-- ============================================================
CREATE TABLE IF NOT EXISTS stream_sessions (
    id              UUID NOT NULL DEFAULT uuid_generate_v4(),
    channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ,
    duration_ms     BIGINT,
    peak_viewers    INTEGER DEFAULT 0,
    total_views     BIGINT DEFAULT 0,
    title           VARCHAR(255),
    metadata        JSONB DEFAULT '{}',
    PRIMARY KEY (id, started_at)
) PARTITION BY RANGE (started_at);

-- Create partitions for 2026
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m01 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m02 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m03 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m04 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m05 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m06 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m07 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m08 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m09 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m10 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m11 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS stream_sessions_y2026m12 PARTITION OF stream_sessions
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_sessions_channel ON stream_sessions(channel_id, started_at DESC);

-- ============================================================
-- WEBHOOK LOGS
-- ============================================================
CREATE TABLE IF NOT EXISTS webhook_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    provider        VARCHAR(32) NOT NULL,
    event_type      VARCHAR(64),
    payload         JSONB NOT NULL,
    processed       BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_webhook_logs_channel ON webhook_logs(channel_id, created_at DESC);

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================

-- Update updated_at on row change
CREATE OR REPLACE FUNCTION update_updated_at() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
CREATE TRIGGER trg_channels_updated_at
    BEFORE UPDATE ON channels
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_platforms_updated_at
    BEFORE UPDATE ON platforms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_clips_updated_at
    BEFORE UPDATE ON clips
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_channel_alerts_updated_at
    BEFORE UPDATE ON channel_alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- LISTEN/NOTIFY for real-time updates
-- ============================================================

-- Notify on channel status changes
CREATE OR REPLACE FUNCTION notify_channel_change() RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('channel_changes', json_build_object(
        'event', TG_OP,
        'channel_id', NEW.id,
        'slug', NEW.slug,
        'status', NEW.status,
        'is_live', NEW.is_live,
        'timestamp', extract(epoch from now())::int
    )::text);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_notify_channel_change
    AFTER INSERT OR UPDATE OF status, is_live ON channels
    FOR EACH ROW EXECUTE FUNCTION notify_channel_change();

-- Notify on clip changes
CREATE OR REPLACE FUNCTION notify_clip_change() RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify('clip_changes', json_build_object(
        'event', TG_OP,
        'channel_id', COALESCE(NEW.channel_id, OLD.channel_id),
        'clip_id', COALESCE(NEW.id, OLD.id),
        'timestamp', extract(epoch from now())::int
    )::text);
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_notify_clip_change
    AFTER INSERT OR UPDATE OR DELETE ON clips
    FOR EACH ROW EXECUTE FUNCTION notify_clip_change();
