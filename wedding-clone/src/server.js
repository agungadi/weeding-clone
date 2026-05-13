const path = require("path");
const dotenv = require("dotenv");
const express = require("express");
const helmet = require("helmet");

dotenv.config({ path: path.resolve(__dirname, "..", ".env") });

const { pool } = require("./db");

const app = express();
const rootDir = path.resolve(__dirname, "..");
const PORT = Number(process.env.PORT || 4173);

app.use(
  helmet({
    contentSecurityPolicy: false
  })
);
app.use(express.json({ limit: "256kb" }));
app.use(express.urlencoded({ extended: false }));
app.use(express.static(rootDir));

function cleanText(value, max = 500) {
  if (typeof value !== "string") return "";
  return value.trim().replace(/\s+/g, " ").slice(0, max);
}

function normalizeGuestAlias(value, max = 120) {
  const cleaned = cleanText(value, max).toLowerCase();
  if (!cleaned) return "";
  return cleaned
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, max);
}

function badRequest(res, message) {
  return res.status(400).json({ error: message });
}

async function getInvitationBySlug(slug) {
  const query = `
    SELECT id, slug, title, bride_name, groom_name, event_date::text AS event_date, event_time,
           venue_name, venue_address, maps_url, is_published
    FROM invitations
    WHERE slug = $1
    LIMIT 1
  `;
  const { rows } = await pool.query(query, [slug]);
  return rows[0] || null;
}

async function getGuestByAlias(invitationId, guestAlias) {
  const query = `
    SELECT id, invitation_id, guest_alias, full_name, group_name, max_guest_count, is_active
    FROM invitation_guests
    WHERE invitation_id = $1 AND guest_alias = $2
    LIMIT 1
  `;
  const { rows } = await pool.query(query, [invitationId, guestAlias]);
  return rows[0] || null;
}

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    return res.json({ ok: true });
  } catch (err) {
    return res.status(500).json({ ok: false, error: err.message });
  }
});

app.get("/api/invitations/:slug", async (req, res) => {
  try {
    const slug = cleanText(req.params.slug, 120).toLowerCase();
    if (!slug) return badRequest(res, "slug is required");
    const invitation = await getInvitationBySlug(slug);
    if (!invitation || !invitation.is_published) {
      return res.status(404).json({ error: "invitation not found" });
    }
    return res.json({ data: invitation });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.get("/api/guest-context", async (req, res) => {
  try {
    const slug = cleanText(req.query.slug || "", 120).toLowerCase();
    const guestAlias = normalizeGuestAlias(req.query.guest_alias || "");
    if (!slug) return badRequest(res, "slug is required");
    if (!guestAlias) return badRequest(res, "guest_alias is required");

    const invitation = await getInvitationBySlug(slug);
    if (!invitation || !invitation.is_published) {
      return res.status(404).json({ error: "invitation not found" });
    }

    const guest = await getGuestByAlias(invitation.id, guestAlias);
    if (!guest || !guest.is_active) {
      return res.status(403).json({ error: "guest is not allowed" });
    }

    const { rows: wishRows } = await pool.query(
      `
      SELECT EXISTS (
        SELECT 1
        FROM wishes
        WHERE invitation_id = $1 AND guest_id = $2
      ) AS wish_submitted
      `,
      [invitation.id, guest.id]
    );
    const wishSubmitted = Boolean(wishRows[0] && wishRows[0].wish_submitted);

    return res.json({
      data: {
        invitation_slug: invitation.slug,
        guest_alias: guest.guest_alias,
        full_name: guest.full_name,
        group_name: guest.group_name,
        max_guest_count: guest.max_guest_count,
        wish_submitted: wishSubmitted
      }
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.get("/api/guest-submission", async (req, res) => {
  try {
    const slug = cleanText(req.query.slug || "", 120).toLowerCase();
    const guestAlias = normalizeGuestAlias(req.query.guest_alias || "");
    if (!slug) return badRequest(res, "slug is required");
    if (!guestAlias) return badRequest(res, "guest_alias is required");

    const invitation = await getInvitationBySlug(slug);
    if (!invitation || !invitation.is_published) {
      return res.status(404).json({ error: "invitation not found" });
    }

    const guest = await getGuestByAlias(invitation.id, guestAlias);
    if (!guest || !guest.is_active) {
      return res.status(403).json({ error: "guest is not allowed" });
    }

    const { rows } = await pool.query(
      `
      SELECT
        w.message AS wish_message,
        w.created_at AS wish_created_at,
        r.status AS rsvp_status,
        r.guest_count AS rsvp_guest_count,
        r.created_at AS rsvp_created_at
      FROM invitation_guests AS g
      LEFT JOIN LATERAL (
        SELECT message, created_at
        FROM wishes
        WHERE invitation_id = $1 AND guest_id = g.id
        ORDER BY created_at DESC
        LIMIT 1
      ) AS w ON TRUE
      LEFT JOIN LATERAL (
        SELECT status, guest_count, created_at
        FROM rsvps
        WHERE invitation_id = $1 AND guest_id = g.id
        ORDER BY created_at DESC
        LIMIT 1
      ) AS r ON TRUE
      WHERE g.invitation_id = $1 AND g.id = $2
      LIMIT 1
      `,
      [invitation.id, guest.id]
    );

    const submission = rows[0] || null;
    return res.json({ data: submission });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.get("/api/wishes", async (req, res) => {
  try {
    const slug = cleanText(req.query.slug || "", 120).toLowerCase();
    const pageRaw = Number(req.query.page || 1);
    const perPageRaw = Number(req.query.per_page || 5);
    const page = Number.isFinite(pageRaw) && pageRaw > 0 ? Math.floor(pageRaw) : 1;
    const perPage = Number.isFinite(perPageRaw) && perPageRaw > 0
      ? Math.min(Math.floor(perPageRaw), 20)
      : 5;
    let offset = (page - 1) * perPage;
    if (!slug) return badRequest(res, "slug is required");
    const invitation = await getInvitationBySlug(slug);
    if (!invitation) return res.status(404).json({ error: "invitation not found" });

    const { rows: countRows } = await pool.query(
      `
      SELECT COUNT(*)::int AS total_items
      FROM wishes
      WHERE invitation_id = $1
      `,
      [invitation.id]
    );
    const totalItems = Number(countRows[0]?.total_items || 0);
    const totalPages = Math.max(1, Math.ceil(totalItems / perPage));
    const effectivePage = Math.min(page, totalPages);
    offset = (effectivePage - 1) * perPage;

    const { rows } = await pool.query(
      `
      SELECT
        COALESCE(g.full_name, w.sender_name) AS sender_name,
        g.guest_alias,
        w.message,
        w.created_at
      FROM wishes AS w
      LEFT JOIN invitation_guests AS g ON g.id = w.guest_id
      WHERE w.invitation_id = $1
      ORDER BY w.created_at DESC
      LIMIT $2 OFFSET $3
      `,
      [invitation.id, perPage, offset]
    );
    return res.json({
      data: rows,
      pagination: {
        page: effectivePage,
        per_page: perPage,
        total_items: totalItems,
        total_pages: totalPages
      }
    });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.get("/api/rsvps/stats", async (req, res) => {
  try {
    const slug = cleanText(req.query.slug || "", 120).toLowerCase();
    if (!slug) return badRequest(res, "slug is required");
    const invitation = await getInvitationBySlug(slug);
    if (!invitation || !invitation.is_published) {
      return res.status(404).json({ error: "invitation not found" });
    }

    const { rows } = await pool.query(
      `
      SELECT
        COUNT(*) FILTER (WHERE status = 'hadir')::int AS hadir,
        COUNT(*) FILTER (WHERE status = 'tidak_hadir')::int AS tidak_hadir,
        COUNT(*) FILTER (WHERE status = 'ragu')::int AS ragu,
        COUNT(*)::int AS total
      FROM rsvps
      WHERE invitation_id = $1
      `,
      [invitation.id]
    );

    return res.json({ data: rows[0] || { hadir: 0, tidak_hadir: 0, ragu: 0, total: 0 } });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.post("/api/rsvps", async (req, res) => {
  try {
    const slug = cleanText(req.body.slug || "", 120).toLowerCase();
    const guestAlias = normalizeGuestAlias(req.body.guest_alias || "");
    const status = cleanText(req.body.status || "", 20).toLowerCase();
    const message = cleanText(req.body.message || "", 500);
    const guestCountRaw = Number(req.body.guest_count || 1);

    if (!slug) return badRequest(res, "slug is required");
    if (!guestAlias) return badRequest(res, "guest_alias is required");
    if (!["hadir", "tidak_hadir", "ragu"].includes(status)) {
      return badRequest(res, "status must be hadir/tidak_hadir/ragu");
    }

    const invitation = await getInvitationBySlug(slug);
    if (!invitation || !invitation.is_published) {
      return res.status(404).json({ error: "invitation not found" });
    }
    const guest = await getGuestByAlias(invitation.id, guestAlias);
    if (!guest || !guest.is_active) {
      return res.status(403).json({ error: "guest is not allowed" });
    }

    const maxGuestCount = Number.isFinite(Number(guest.max_guest_count))
      ? Math.max(0, Math.min(Number(guest.max_guest_count), 20))
      : 1;
    const guestCount = Number.isFinite(guestCountRaw)
      ? Math.max(0, Math.min(guestCountRaw, maxGuestCount))
      : Math.min(1, maxGuestCount);

    await pool.query(
      `
      INSERT INTO rsvps (invitation_id, guest_id, guest_name, status, guest_count, message)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (invitation_id, guest_id)
      DO UPDATE SET
        guest_name = EXCLUDED.guest_name,
        status = EXCLUDED.status,
        guest_count = EXCLUDED.guest_count,
        message = EXCLUDED.message,
        created_at = NOW()
      `,
      [invitation.id, guest.id, guest.full_name, status, guestCount, message || null]
    );

    return res.status(201).json({ message: "RSVP saved", guest_name: guest.full_name });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.post("/api/wishes", async (req, res) => {
  try {
    const slug = cleanText(req.body.slug || "", 120).toLowerCase();
    const guestAlias = normalizeGuestAlias(req.body.guest_alias || "");
    const message = cleanText(req.body.message || "", 800);

    if (!slug) return badRequest(res, "slug is required");
    if (!guestAlias) return badRequest(res, "guest_alias is required");
    if (!message) return badRequest(res, "message is required");

    const invitation = await getInvitationBySlug(slug);
    if (!invitation || !invitation.is_published) {
      return res.status(404).json({ error: "invitation not found" });
    }
    const guest = await getGuestByAlias(invitation.id, guestAlias);
    if (!guest || !guest.is_active) {
      return res.status(403).json({ error: "guest is not allowed" });
    }

    const { rows: wishRows } = await pool.query(
      `
      SELECT EXISTS (
        SELECT 1
        FROM wishes
        WHERE invitation_id = $1 AND guest_id = $2
      ) AS wish_submitted
      `,
      [invitation.id, guest.id]
    );
    if (wishRows[0] && wishRows[0].wish_submitted) {
      return res.status(409).json({ error: "wish already submitted" });
    }

    await pool.query(
      `
      INSERT INTO wishes (invitation_id, guest_id, sender_name, message)
      VALUES ($1, $2, $3, $4)
      `,
      [invitation.id, guest.id, guest.full_name, message]
    );

    return res.status(201).json({ message: "Wish saved", sender_name: guest.full_name });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.get("/", (_req, res) => {
  return res.sendFile(path.resolve(rootDir, "index.html"));
});

const reservedGuestAliases = new Set([
  "api",
  "health",
  "mirror",
  "src",
  "db",
  "node_modules",
  "favicon.ico",
  "robots.txt",
  "sitemap.xml"
]);

app.get("/:guestAlias", (req, res, next) => {
  const alias = normalizeGuestAlias(req.params.guestAlias || "");
  if (!alias || reservedGuestAliases.has(alias)) return next();
  return res.sendFile(path.resolve(rootDir, "index.html"));
});

app.listen(PORT, () => {
  console.log(`Server running on http://127.0.0.1:${PORT}`);
});
