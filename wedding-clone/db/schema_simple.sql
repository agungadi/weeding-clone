BEGIN;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS invitations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug            TEXT NOT NULL UNIQUE,
  title           TEXT NOT NULL,
  bride_name      TEXT NOT NULL,
  groom_name      TEXT NOT NULL,
  event_date      DATE NOT NULL,
  event_time      TEXT NOT NULL,
  venue_name      TEXT NOT NULL,
  venue_address   TEXT NOT NULL,
  maps_url        TEXT,
  is_published    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

CREATE TABLE IF NOT EXISTS invitation_guests (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id     UUID NOT NULL REFERENCES invitations(id) ON DELETE CASCADE,
  guest_alias       TEXT NOT NULL,
  full_name         TEXT NOT NULL,
  group_name        TEXT,
  max_guest_count   INT NOT NULL DEFAULT 1 CHECK (max_guest_count >= 0 AND max_guest_count <= 20),
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_invitation_guests_alias UNIQUE (invitation_id, guest_alias),
  CHECK (guest_alias ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

CREATE INDEX IF NOT EXISTS idx_invitation_guests_invitation_id ON invitation_guests(invitation_id);
CREATE INDEX IF NOT EXISTS idx_invitation_guests_alias ON invitation_guests(guest_alias);

CREATE TABLE IF NOT EXISTS rsvps (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id   UUID NOT NULL REFERENCES invitations(id) ON DELETE CASCADE,
  guest_id        UUID,
  guest_name      TEXT NOT NULL,
  status          TEXT NOT NULL CHECK (status IN ('hadir', 'tidak_hadir', 'ragu')),
  guest_count     INT NOT NULL DEFAULT 1 CHECK (guest_count >= 0),
  message         TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rsvps_invitation_id ON rsvps(invitation_id);
CREATE INDEX IF NOT EXISTS idx_rsvps_created_at ON rsvps(created_at DESC);

CREATE TABLE IF NOT EXISTS wishes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invitation_id   UUID NOT NULL REFERENCES invitations(id) ON DELETE CASCADE,
  guest_id        UUID,
  sender_name     TEXT NOT NULL,
  message         TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wishes_invitation_id ON wishes(invitation_id);
CREATE INDEX IF NOT EXISTS idx_wishes_created_at ON wishes(created_at DESC);

ALTER TABLE rsvps
  ADD COLUMN IF NOT EXISTS guest_id UUID;

ALTER TABLE wishes
  ADD COLUMN IF NOT EXISTS guest_id UUID;

CREATE INDEX IF NOT EXISTS idx_rsvps_guest_id ON rsvps(guest_id);
CREATE INDEX IF NOT EXISTS idx_wishes_guest_id ON wishes(guest_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_rsvps_guest_id'
  ) THEN
    ALTER TABLE rsvps
      ADD CONSTRAINT fk_rsvps_guest_id
      FOREIGN KEY (guest_id) REFERENCES invitation_guests(id) ON DELETE SET NULL;
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_wishes_guest_id'
  ) THEN
    ALTER TABLE wishes
      ADD CONSTRAINT fk_wishes_guest_id
      FOREIGN KEY (guest_id) REFERENCES invitation_guests(id) ON DELETE SET NULL;
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_rsvps_invitation_guest'
  ) THEN
    ALTER TABLE rsvps
      ADD CONSTRAINT uq_rsvps_invitation_guest UNIQUE (invitation_id, guest_id);
  END IF;
END
$$;

COMMIT;
