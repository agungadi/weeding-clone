# Wedding Invitation (Rosa & Adi) - Local Dev Guide

Project ini adalah undangan pernikahan berbasis `index.html` (clone template) yang sudah diintegrasikan ke backend Node.js + PostgreSQL untuk:

- validasi tamu berdasarkan whitelist (`guest_alias`)
- simpan RSVP
- simpan Ucapan/Doa (Wishes)

## Stack

- Node.js `>= 20`
- Express.js
- PostgreSQL 16
- HTML/CSS/JS statis (`index.html`)

## Fitur Utama

- URL tamu per alias, contoh: `/rudi`
- hanya tamu terdaftar yang bisa kirim RSVP/Wishes
- 1 tamu hanya bisa kirim 1 wishes
- RSVP bersifat upsert (data kehadiran tamu diperbarui)
- counter hadir/tidak hadir dan list ucapan diambil dari database

## Struktur Project

- `index.html` - template undangan + script frontend RSVP/Wishes
- `src/server.js` - static server + API
- `src/migrate.js` - jalankan migrasi schema
- `src/seed.js` - jalankan seed data awal
- `db/schema_simple.sql` - schema utama PostgreSQL
- `db/seed_simple.sql` - data awal undangan + daftar tamu contoh
- `docker-compose.yml` - PostgreSQL lokal via Docker

## Quick Start (Local)

### 1) Masuk folder project

```bash
cd "/Users/agungadi/Documents/New project/wedding-clone"
```

### 2) Siapkan environment

```bash
cp .env.example .env
```

Default `.env`:

```env
PORT=4173
DATABASE_URL=postgresql://postgres:postgres@127.0.0.1:5432/wedding_invitation
PUBLIC_BASE_URL=http://127.0.0.1:4173
```

### 3) Jalankan PostgreSQL

Opsi A (disarankan, Docker):

```bash
docker compose up -d
```

Opsi B (PostgreSQL lokal non-Docker):

```bash
brew services start postgresql@16
```

Pastikan `DATABASE_URL` sesuai host/user/password database lokal Anda.

### 4) Install dependency

```bash
npm install
```

### 5) Migrasi dan seed data

```bash
npm run db:migrate
npm run db:seed
```

Command ini aman dijalankan berulang karena schema/seed disusun idempotent.

### 6) Jalankan aplikasi

```bash
npm run dev
```

Server jalan di:

- `http://127.0.0.1:4173`

## Cara Akses Undangan Tamu

Contoh URL tamu:

- `http://127.0.0.1:4173/rudi`
- `http://127.0.0.1:4173/budi-keluarga`
- `http://127.0.0.1:4173/siti`

Alias diambil dari kolom `invitation_guests.guest_alias`.

## Rules RSVP/Wishes di Project Ini

- Form RSVP/Wishes aktif hanya jika guest valid di tabel `invitation_guests`.
- Nama pengirim mengikuti `full_name` dari database (bukan input bebas).
- Wishes hanya 1 kali per guest (`POST /api/wishes` akan `409` jika sudah pernah kirim).
- RSVP tersimpan per guest per invitation (`UNIQUE (invitation_id, guest_id)`).

## Tambah / Edit Daftar Tamu

Contoh tambah tamu baru untuk undangan `rosa-adi-2026`:

```sql
INSERT INTO invitation_guests (
  invitation_id,
  guest_alias,
  full_name,
  group_name,
  max_guest_count,
  is_active
)
SELECT
  id,
  'andi-keluarga',
  'Andi & Keluarga',
  'Keluarga',
  4,
  TRUE
FROM invitations
WHERE slug = 'rosa-adi-2026';
```

Setelah itu tamu bisa akses:

- `http://127.0.0.1:4173/andi-keluarga`

## Endpoint Ringkas (untuk integrasi/testing)

- `GET /health`
- `GET /api/invitations/:slug`
- `GET /api/guest-context?slug=...&guest_alias=...`
- `GET /api/guest-submission?slug=...&guest_alias=...`
- `GET /api/wishes?slug=...`
- `GET /api/rsvps/stats?slug=...`
- `POST /api/rsvps`
- `POST /api/wishes`

## Troubleshooting

### Port `4173` sudah dipakai

Ganti `PORT` di `.env`, lalu restart:

```bash
PORT=4174 npm run dev
```

### Gagal konek database

- cek Postgres sudah jalan
- cek `DATABASE_URL`
- cek port `5432` tidak bentrok

### Submit form tidak masuk database

- pastikan akses via URL alias tamu valid (`/rudi`, dst.)
- cek tamu ada di `invitation_guests` dan `is_active = true`
- cek log terminal backend saat submit

## Catatan untuk Push ke GitHub

- commit file source project
- jangan commit `.env` (sudah di `.gitignore`)
- sebelum push, pastikan langkah pada bagian "Quick Start (Local)" bisa dijalankan dari awal oleh rekan tim

## Catatan Deploy VPS (Ringkas)

- pisahkan service `app` dan `postgres`
- simpan env di server, jangan di repo
- gunakan reverse proxy (Nginx/Caddy) + HTTPS
- backup database berkala (`pg_dump`)
