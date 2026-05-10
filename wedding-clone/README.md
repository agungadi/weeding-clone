# Wedding Invitation (Simple + PostgreSQL)

Template undangan tetap memakai HTML hasil clone (`index.html`), lalu ditambahkan backend simple untuk:

- Daftar tamu terdaftar (whitelist)
- RSVP
- Ucapan/Doa

Data disimpan ke PostgreSQL.

## 1) Siapkan env

```bash
cd "/Users/agungadi/Documents/New project/wedding-clone"
cp .env.example .env
```

## 2) Jalankan PostgreSQL lokal (Docker)

```bash
docker compose up -d
```

Jika Docker daemon belum aktif, alternatif cepat:

```bash
brew services start postgresql@16
```

## 3) Install dependency backend

```bash
npm install
```

## 4) Apply migration + seed

```bash
npm run db:migrate
npm run db:seed
```

## 5) Run app

```bash
npm run dev
```

Buka:

- `http://127.0.0.1:4173/rudi`

Contoh lain (sesuai alias di tabel tamu):

- `http://127.0.0.1:4173/budi-keluarga`

Catatan:

- RSVP/Ucapan hanya bisa dikirim jika `guest_alias` ada di tabel `invitation_guests`.
- Nama pengirim diambil dari data tamu terdaftar (bukan input bebas).

## Struktur penting

- `db/schema_simple.sql`: schema PostgreSQL MVP (invitations, invitation_guests, rsvps, wishes)
- `db/seed_simple.sql`: seed invitation awal (`rosa-adi-2026`) + contoh daftar tamu (`rudi`, `budi-keluarga`, dll.)
- `src/server.js`: API + static server
- `index.html`: template undangan + form RSVP/Ucapan yang terhubung API

## Catatan deploy VPS (best-practice dasar)

- Pisahkan service: `app` dan `postgres`
- Simpan `.env` di server (jangan commit)
- Gunakan reverse proxy (Nginx) + HTTPS
- Backup database terjadwal (`pg_dump`)
