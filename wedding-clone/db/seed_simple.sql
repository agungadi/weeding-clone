WITH upsert_invitation AS (
INSERT INTO invitations (
  slug,
  title,
  bride_name,
  groom_name,
  event_date,
  event_time,
  venue_name,
  venue_address,
  maps_url,
  is_published
)
VALUES (
  'rosa-adi-2026',
  'The Wedding Of Rosa & Adi',
  'Rosa Nur Madinah',
  'Agung Adi Saputra',
  DATE '2026-05-28',
  'Akad 08.00 - 09.00, Resepsi 13.30 - 14.30',
  'GEDUNG SERBAGUNA (AULA) ITN KAMPUS 1',
  'Jl. Sigura - Gura No.02, Sumbersari, Kec. Lowokwaru, Kota Malang, Jawa Timur 65145',
  'https://maps.google.com/?q=Gedung+Serbaguna+(Aula)+ITN+Kampus+1,+Jl.+Sigura-Gura+No.02,+Sumbersari,+Kec.+Lowokwaru,+Kota+Malang,+Jawa+Timur+65145',
  TRUE
)
ON CONFLICT (slug) DO UPDATE
SET
  title = EXCLUDED.title,
  bride_name = EXCLUDED.bride_name,
  groom_name = EXCLUDED.groom_name,
  event_date = EXCLUDED.event_date,
  event_time = EXCLUDED.event_time,
  venue_name = EXCLUDED.venue_name,
  venue_address = EXCLUDED.venue_address,
  maps_url = EXCLUDED.maps_url,
  is_published = EXCLUDED.is_published,
  updated_at = NOW()
RETURNING id
)
INSERT INTO invitation_guests (
  invitation_id,
  guest_alias,
  full_name,
  group_name,
  max_guest_count,
  is_active
)
SELECT
  inv.id,
  g.guest_alias,
  g.full_name,
  g.group_name,
  g.max_guest_count,
  TRUE
FROM upsert_invitation AS inv
CROSS JOIN (
  VALUES
    ('rudi', 'Rudi', 'Teman', 1),
    ('budi-keluarga', 'Budi & Keluarga', 'Keluarga', 4),
    ('siti', 'Siti', 'Teman', 1),
    ('dedi', 'Dedi', 'Rekan Kerja', 2)
) AS g(guest_alias, full_name, group_name, max_guest_count)
ON CONFLICT (invitation_id, guest_alias) DO UPDATE
SET
  full_name = EXCLUDED.full_name,
  group_name = EXCLUDED.group_name,
  max_guest_count = EXCLUDED.max_guest_count,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();
