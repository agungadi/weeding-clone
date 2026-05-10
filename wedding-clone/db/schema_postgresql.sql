-- Wedding Invitation App - PostgreSQL Schema
-- PostgreSQL 14+

BEGIN;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

-- ===== ENUMS =====
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE user_role AS ENUM ('owner', 'admin', 'editor');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'wedding_status') THEN
    CREATE TYPE wedding_status AS ENUM ('draft', 'published', 'archived');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_type') THEN
    CREATE TYPE event_type AS ENUM ('akad', 'resepsi', 'engagement', 'other');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rsvp_status') THEN
    CREATE TYPE rsvp_status AS ENUM ('hadir', 'tidak_hadir', 'ragu');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'gift_type') THEN
    CREATE TYPE gift_type AS ENUM ('bank_transfer', 'ewallet', 'shipping_address');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'media_type') THEN
    CREATE TYPE media_type AS ENUM ('photo', 'video', 'audio');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'stream_platform') THEN
    CREATE TYPE stream_platform AS ENUM ('youtube', 'instagram', 'zoom', 'tiktok', 'other');
  END IF;
END$$;

-- ===== USERS =====
CREATE TABLE IF NOT EXISTS app_users (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name           TEXT NOT NULL,
  email               CITEXT NOT NULL UNIQUE,
  password_hash       TEXT NOT NULL,
  role                user_role NOT NULL DEFAULT 'owner',
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===== MAIN WEDDING =====
CREATE TABLE IF NOT EXISTS weddings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id       UUID NOT NULL REFERENCES app_users(id) ON DELETE RESTRICT,
  slug                TEXT NOT NULL UNIQUE,
  title               TEXT NOT NULL,
  subtitle            TEXT,
  timezone            TEXT NOT NULL DEFAULT 'Asia/Jakarta',
  language_code       TEXT NOT NULL DEFAULT 'id',
  status              wedding_status NOT NULL DEFAULT 'draft',
  theme_key           TEXT NOT NULL DEFAULT 'premium-07',
  cover_image_url     TEXT,
  background_music_url TEXT,
  publish_at          TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

-- ===== COUPLE PROFILE =====
CREATE TABLE IF NOT EXISTS couple_profiles (
  wedding_id              UUID PRIMARY KEY REFERENCES weddings(id) ON DELETE CASCADE,
  bride_nickname          TEXT NOT NULL,
  bride_full_name         TEXT NOT NULL,
  bride_father_name       TEXT,
  bride_mother_name       TEXT,
  groom_nickname          TEXT NOT NULL,
  groom_full_name         TEXT NOT NULL,
  groom_father_name       TEXT,
  groom_mother_name       TEXT,
  opening_greeting        TEXT,
  closing_greeting        TEXT,
  quote_text              TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===== WEDDING EVENTS =====
CREATE TABLE IF NOT EXISTS wedding_events (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  event_type          event_type NOT NULL,
  title               TEXT NOT NULL,
  starts_at           TIMESTAMPTZ NOT NULL,
  ends_at             TIMESTAMPTZ,
  note                TEXT,
  is_private          BOOLEAN NOT NULL DEFAULT FALSE,
  venue_name          TEXT,
  venue_address       TEXT,
  maps_url            TEXT,
  latitude            NUMERIC(10, 7),
  longitude           NUMERIC(10, 7),
  sort_order          INT NOT NULL DEFAULT 100,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (ends_at IS NULL OR ends_at >= starts_at)
);

CREATE INDEX IF NOT EXISTS idx_wedding_events_wedding_id ON wedding_events(wedding_id);
CREATE INDEX IF NOT EXISTS idx_wedding_events_start ON wedding_events(starts_at);

-- ===== LOVE STORY =====
CREATE TABLE IF NOT EXISTS love_story_items (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  title               TEXT NOT NULL,
  story_date          DATE,
  description         TEXT NOT NULL,
  sort_order          INT NOT NULL DEFAULT 100,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_love_story_wedding_id ON love_story_items(wedding_id);

-- ===== GALLERY / MEDIA =====
CREATE TABLE IF NOT EXISTS media_assets (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  media_type          media_type NOT NULL,
  url                 TEXT NOT NULL,
  thumbnail_url       TEXT,
  caption             TEXT,
  sort_order          INT NOT NULL DEFAULT 100,
  is_cover            BOOLEAN NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_media_assets_wedding_id ON media_assets(wedding_id);

-- ===== LIVE STREAMING =====
CREATE TABLE IF NOT EXISTS livestream_links (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  platform            stream_platform NOT NULL,
  title               TEXT NOT NULL,
  url                 TEXT NOT NULL,
  starts_at           TIMESTAMPTZ,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_livestream_wedding_id ON livestream_links(wedding_id);

-- ===== GIFT / AMPLOP DIGITAL =====
CREATE TABLE IF NOT EXISTS gift_channels (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  gift_kind           gift_type NOT NULL,
  provider_name       TEXT,
  account_name        TEXT,
  account_number      TEXT,
  qr_image_url        TEXT,
  shipping_recipient  TEXT,
  shipping_address    TEXT,
  sort_order          INT NOT NULL DEFAULT 100,
  is_active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_gift_channels_wedding_id ON gift_channels(wedding_id);

-- ===== GUEST & RSVP =====
CREATE TABLE IF NOT EXISTS guest_groups (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  name                TEXT NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (wedding_id, name)
);

CREATE TABLE IF NOT EXISTS guests (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  guest_group_id      UUID REFERENCES guest_groups(id) ON DELETE SET NULL,
  full_name           TEXT NOT NULL,
  phone               TEXT,
  email               CITEXT,
  invite_token        TEXT NOT NULL UNIQUE,
  qr_token            TEXT NOT NULL UNIQUE,
  pax_limit           INT NOT NULL DEFAULT 1 CHECK (pax_limit > 0),
  is_vip              BOOLEAN NOT NULL DEFAULT FALSE,
  note                TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_guests_wedding_id ON guests(wedding_id);
CREATE INDEX IF NOT EXISTS idx_guests_group_id ON guests(guest_group_id);

CREATE TABLE IF NOT EXISTS rsvps (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  guest_id            UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
  status              rsvp_status NOT NULL,
  attending_count     INT NOT NULL DEFAULT 1 CHECK (attending_count >= 0),
  message             TEXT,
  responded_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (wedding_id, guest_id)
);

CREATE INDEX IF NOT EXISTS idx_rsvps_wedding_id ON rsvps(wedding_id);
CREATE INDEX IF NOT EXISTS idx_rsvps_status ON rsvps(status);

-- ===== WISHES / GUESTBOOK =====
CREATE TABLE IF NOT EXISTS wishes (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  guest_id            UUID REFERENCES guests(id) ON DELETE SET NULL,
  sender_name         TEXT NOT NULL,
  message             TEXT NOT NULL,
  attendance_status   rsvp_status,
  is_approved         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wishes_wedding_id ON wishes(wedding_id);
CREATE INDEX IF NOT EXISTS idx_wishes_approved ON wishes(is_approved);

-- ===== RSVP CHECK-IN (QR) =====
CREATE TABLE IF NOT EXISTS checkins (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  guest_id            UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
  checked_in_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  gate_name           TEXT,
  checked_by_user_id  UUID REFERENCES app_users(id) ON DELETE SET NULL,
  UNIQUE (wedding_id, guest_id)
);

CREATE INDEX IF NOT EXISTS idx_checkins_wedding_id ON checkins(wedding_id);

-- ===== ANALYTICS =====
CREATE TABLE IF NOT EXISTS invitation_views (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wedding_id          UUID NOT NULL REFERENCES weddings(id) ON DELETE CASCADE,
  guest_id            UUID REFERENCES guests(id) ON DELETE SET NULL,
  viewed_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_address          INET,
  user_agent          TEXT,
  referrer            TEXT
);

CREATE INDEX IF NOT EXISTS idx_invitation_views_wedding_id ON invitation_views(wedding_id);
CREATE INDEX IF NOT EXISTS idx_invitation_views_viewed_at ON invitation_views(viewed_at);

COMMIT;

