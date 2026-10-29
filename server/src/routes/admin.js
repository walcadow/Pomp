// Basit yönetici paneli: http://localhost:3000/admin
// Giriş şifresi .env dosyasındaki ADMIN_PASSWORD'dür. Tanımlı değilse panel kapalıdır.
const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const rateLimit = require('express-rate-limit');
const { z } = require('zod');
const db = require('../db');
const config = require('../config');
const realtime = require('../realtime');
const { wrap, HttpError, ageFromBirthdate, photoUrl, parse } = require('../util');

const router = express.Router();
const api = express.Router();

const PUBLIC_DIR = path.join(__dirname, '..', '..', 'public', 'admin');
const TOKEN_AUDIENCE = 'pomp-admin';
const PAGE_SIZE = 50;
const DISABLED_MSG = 'Yönetici paneli kapalı: .env dosyasına ADMIN_PASSWORD ekleyin.';

// Panel sayfaları için daha esnek bir güvenlik politikası: fotoğraflar başka adreslerden
// (ui-avatars.com, PUBLIC_URL) gelebilir. Betikler yine yalnızca bu sunucudan yüklenir.
router.use((req, res, next) => {
  res.setHeader(
    'Content-Security-Policy',
    "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; " +
      "img-src 'self' data: https: http:; connect-src 'self'; object-src 'none'; " +
      "base-uri 'self'; form-action 'self'; frame-ancestors 'none'"
  );
  res.setHeader('X-Robots-Tag', 'noindex, nofollow');
  res.setHeader('Cache-Control', 'no-store');
  next();
});

// ---------- Giriş ----------

function adminPassword() {
  // Varsayılan şifre yok: docker-compose varsayılan olarak NODE_ENV=development ile çalıştığı için
  // bilinen bir varsayılan şifre, internete açık sunucularda paneli herkese açardı.
  return process.env.ADMIN_PASSWORD || '';
}

function sha256(value) {
  return crypto.createHash('sha256').update(String(value), 'utf8').digest();
}

// Şifre değişirse eski oturumlar geçersiz olsun diye jetona şifrenin kısa bir izi eklenir.
function passwordTag() {
  return crypto.createHmac('sha256', config.jwtSecret).update(adminPassword()).digest('hex').slice(0, 16);
}

function passwordMatches(input) {
  // Karşılaştırma süresi şifrenin doğruluğunu ele vermesin diye özetler sabit sürede karşılaştırılır.
  return crypto.timingSafeEqual(sha256(input), sha256(adminPassword()));
}

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  skipSuccessfulRequests: true,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla hatalı deneme yaptınız. 15 dakika sonra tekrar deneyin.' },
});

function requireEnabled(req, res, next) {
  if (!adminPassword()) return res.status(503).json({ error: DISABLED_MSG, disabled: true });
  next();
}

function requireAdmin(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Giriş yapmanız gerekiyor.' });
  try {
    const payload = jwt.verify(token, config.jwtSecret, { audience: TOKEN_AUDIENCE });
    if (payload.admin !== true || payload.pw !== passwordTag()) throw new Error('invalid');
  } catch {
    return res.status(401).json({ error: 'Oturumunuzun süresi doldu, tekrar giriş yapın.' });
  }
  next();
}

api.get('/status', (req, res) => {
  res.json({ enabled: Boolean(adminPassword()) });
});

api.use(requireEnabled);

api.post('/login', loginLimiter, (req, res) => {
  const password = req.body && typeof req.body.password === 'string' ? req.body.password : '';
  if (!password || !passwordMatches(password)) {
    return res.status(401).json({ error: 'Şifre hatalı.' });
  }
  const token = jwt.sign({ admin: true, pw: passwordTag() }, config.jwtSecret, {
    expiresIn: '12h',
    audience: TOKEN_AUDIENCE,
  });
  res.json({ token });
});

api.use(requireAdmin);

// ---------- Yardımcılar ----------

const uuidSchema = z.string().uuid();
function idParam(req, notFoundMsg) {
  const result = uuidSchema.safeParse(req.params.id);
  if (!result.success) throw new HttpError(404, notFoundMsg);
  return result.data;
}

function deleteLocalPhoto(url) {
  if (!url || !url.startsWith('/uploads/')) return;
  const file = path.join(config.uploadDir, path.basename(url));
  fs.promises.unlink(file).catch(() => {});
}

// Raporlarda kullanılan kısa kullanıcı özeti (JSON nesnesi olarak SQL'den gelir).
const USER_BRIEF = (alias) => `
  CASE WHEN ${alias}.id IS NULL THEN NULL ELSE json_build_object(
    'id', ${alias}.id,
    'name', ${alias}.name,
    'email', ${alias}.email,
    'birthdate', ${alias}.birthdate::text,
    'is_banned', ${alias}.is_banned,
    'is_demo', ${alias}.is_demo,
    'photo', (SELECT p.url FROM photos p WHERE p.user_id = ${alias}.id ORDER BY p.position, p.created_at LIMIT 1),
    'reports_count', (SELECT COUNT(*) FROM reports x WHERE x.reported_id = ${alias}.id)
  ) END`;

function briefUser(req, u) {
  if (!u) return null;
  return {
    id: u.id,
    name: u.name,
    email: u.email,
    age: u.birthdate ? ageFromBirthdate(u.birthdate) : null,
    is_banned: u.is_banned,
    is_demo: u.is_demo,
    photo: u.photo ? photoUrl(req, u.photo) : null,
    reports_count: Number(u.reports_count) || 0,
  };
}

function reportRow(req, r) {
  return {
    id: r.id,
    reason: r.reason,
    details: r.details,
    status: r.status,
    created_at: r.created_at,
    resolved_at: r.resolved_at,
    admin_action: r.admin_action,
    admin_note: r.admin_note,
    reporter: briefUser(req, r.reporter),
    reported: briefUser(req, r.reported),
  };
}

// Kullanıcıyı yasaklar, açık şikâyetlerini kapatır ve anlık bağlantısını keser.
async function banUser(client, userId, reason) {
  const { rows } = await client.query(
    `UPDATE users SET is_banned = TRUE, banned_at = COALESCE(banned_at, now()), ban_reason = $2
     WHERE id = $1 RETURNING id`,
    [userId, reason || null]
  );
  if (!rows[0]) return false;
  await client.query(
    `UPDATE reports SET status = 'resolved', resolved_at = now(), admin_action = 'ban',
       admin_note = COALESCE(admin_note, 'Kullanıcı yasaklandı.')
     WHERE reported_id = $1 AND status = 'open'`,
    [userId]
  );
  return true;
}

async function inTransaction(fn) {
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

// ---------- İstatistikler ----------

api.get('/stats', wrap(async (req, res) => {
  const { rows } = await db.query(`
    SELECT
      (SELECT COUNT(*) FROM users)::int AS total_users,
      (SELECT COUNT(*) FROM users WHERE NOT is_demo)::int AS real_users,
      (SELECT COUNT(*) FROM users WHERE NOT is_demo AND last_active_at > now() - interval '24 hours')::int AS active_24h,
      (SELECT COUNT(*) FROM users WHERE NOT is_demo AND created_at > now() - interval '7 days')::int AS new_7d,
      (SELECT COUNT(*) FROM matches)::int AS matches,
      (SELECT COUNT(*) FROM messages WHERE created_at > now() - interval '24 hours')::int AS messages_24h,
      (SELECT COUNT(*) FROM reports WHERE status = 'open')::int AS open_reports,
      (SELECT COUNT(*) FROM users WHERE is_banned)::int AS banned_users
  `);
  res.json(rows[0]);
}));

// ---------- Şikâyetler ----------

api.get('/reports', wrap(async (req, res) => {
  const status = ['open', 'resolved', 'all'].includes(req.query.status) ? req.query.status : 'open';
  const where = status === 'open' ? "r.status = 'open'" : status === 'resolved' ? "r.status <> 'open'" : 'TRUE';
  const { rows } = await db.query(`
    SELECT r.id, r.reason, r.details, r.status, r.created_at, r.resolved_at, r.admin_action, r.admin_note,
      ${USER_BRIEF('rp')} AS reporter,
      ${USER_BRIEF('rd')} AS reported
    FROM reports r
    LEFT JOIN users rp ON rp.id = r.reporter_id
    LEFT JOIN users rd ON rd.id = r.reported_id
    WHERE ${where}
    ORDER BY (r.status = 'open') DESC, r.created_at DESC
    LIMIT 200
  `);
  res.json({ reports: rows.map((r) => reportRow(req, r)) });
}));

const resolveSchema = z.object({
  action: z.enum(['dismiss', 'ban'], { message: 'Geçersiz işlem.' }),
  note: z.string().trim().max(500, 'Not en fazla 500 karakter olabilir.').optional(),
});

api.post('/reports/:id/resolve', wrap(async (req, res) => {
  const id = idParam(req, 'Şikâyet bulunamadı.');
  const { action, note } = parse(resolveSchema, req.body || {});
  const reportedId = await inTransaction(async (client) => {
    const { rows } = await client.query('SELECT reported_id, status FROM reports WHERE id = $1 FOR UPDATE', [id]);
    if (!rows[0]) throw new HttpError(404, 'Şikâyet bulunamadı.');
    if (rows[0].status !== 'open') throw new HttpError(409, 'Bu şikâyet zaten sonuçlandırılmış.');
    await client.query(
      `UPDATE reports SET status = 'resolved', resolved_at = now(), admin_action = $2, admin_note = $3 WHERE id = $1`,
      [id, action, note || null]
    );
    if (action === 'ban' && rows[0].reported_id) {
      await banUser(client, rows[0].reported_id, note || 'Şikâyet üzerine yasaklandı.');
    }
    return rows[0].reported_id;
  });
  if (action === 'ban' && reportedId) realtime.disconnectUser(reportedId);
  res.json({ ok: true });
}));

// ---------- Kullanıcılar ----------

api.get('/users', wrap(async (req, res) => {
  const q = typeof req.query.q === 'string' ? req.query.q.trim().slice(0, 100) : '';
  const page = Math.max(1, Math.min(10000, parseInt(req.query.page, 10) || 1));
  const filter = ['real', 'demo', 'banned', 'reported'].includes(req.query.filter) ? req.query.filter : 'all';

  const conds = [];
  const params = [];
  if (q) {
    params.push('%' + q.replace(/[\\%_]/g, '\\$&') + '%');
    const like = `$${params.length}`;
    params.push(q);
    conds.push(`(u.name ILIKE ${like} OR u.email ILIKE ${like} OR u.id::text = $${params.length})`);
  }
  if (filter === 'real') conds.push('NOT u.is_demo');
  if (filter === 'demo') conds.push('u.is_demo');
  if (filter === 'banned') conds.push('u.is_banned');
  if (filter === 'reported') conds.push('EXISTS (SELECT 1 FROM reports r WHERE r.reported_id = u.id)');
  params.push((page - 1) * PAGE_SIZE);

  const { rows } = await db.query(`
    SELECT u.id, u.name, u.email, u.birthdate::text AS birthdate, u.gender, u.is_banned, u.is_demo,
      u.created_at, u.last_active_at,
      (SELECT COUNT(*) FROM photos p WHERE p.user_id = u.id)::int AS photos_count,
      (SELECT p.url FROM photos p WHERE p.user_id = u.id ORDER BY p.position, p.created_at LIMIT 1) AS photo,
      (SELECT COUNT(*) FROM reports r WHERE r.reported_id = u.id)::int AS reports_against,
      COUNT(*) OVER()::int AS total
    FROM users u
    ${conds.length ? 'WHERE ' + conds.join(' AND ') : ''}
    ORDER BY u.is_demo ASC, u.created_at DESC
    LIMIT ${PAGE_SIZE} OFFSET $${params.length}
  `, params);

  let total = rows[0] ? rows[0].total : 0;
  if (!rows[0] && page > 1) {
    const c = await db.query(
      `SELECT COUNT(*)::int AS n FROM users u ${conds.length ? 'WHERE ' + conds.join(' AND ') : ''}`,
      params.slice(0, -1)
    );
    total = c.rows[0].n;
  }

  res.json({
    page,
    pageSize: PAGE_SIZE,
    total,
    users: rows.map((u) => ({
      id: u.id,
      name: u.name,
      email: u.email,
      age: ageFromBirthdate(u.birthdate),
      gender: u.gender,
      is_banned: u.is_banned,
      is_demo: u.is_demo,
      created_at: u.created_at,
      last_active_at: u.last_active_at,
      photos_count: u.photos_count,
      photo: u.photo ? photoUrl(req, u.photo) : null,
      reports_against: u.reports_against,
    })),
  });
}));

api.get('/users/:id', wrap(async (req, res) => {
  const id = idParam(req, 'Kullanıcı bulunamadı.');
  const { rows } = await db.query(`
    SELECT u.id, u.name, u.email, u.birthdate::text AS birthdate, u.gender, u.interested_in, u.bio, u.interests,
      u.min_age, u.max_age, u.max_distance_km, (u.lat IS NOT NULL) AS has_location,
      u.is_banned, u.is_demo, u.banned_at, u.ban_reason, u.created_at, u.last_active_at,
      (to_jsonb(u) ->> 'email_verified')::boolean AS email_verified,
      (SELECT COUNT(*) FROM matches m WHERE m.user_a = u.id OR m.user_b = u.id)::int AS matches,
      (SELECT COUNT(*) FROM messages m WHERE m.sender_id = u.id)::int AS messages_sent,
      (SELECT COUNT(*) FROM swipes s WHERE s.swiper_id = u.id)::int AS swipes,
      (SELECT COUNT(*) FROM swipes s WHERE s.target_id = u.id AND s.liked)::int AS likes_received,
      (SELECT COUNT(*) FROM reports r WHERE r.reporter_id = u.id)::int AS reports_made,
      (SELECT COUNT(*) FROM blocks b WHERE b.blocked_id = u.id)::int AS blocked_by
    FROM users u WHERE u.id = $1
  `, [id]);
  const u = rows[0];
  if (!u) throw new HttpError(404, 'Kullanıcı bulunamadı.');

  const [photos, reports] = await Promise.all([
    db.query('SELECT id, url, position FROM photos WHERE user_id = $1 ORDER BY position, created_at', [id]),
    db.query(`
      SELECT r.id, r.reason, r.details, r.status, r.created_at, r.resolved_at, r.admin_action, r.admin_note,
        ${USER_BRIEF('rp')} AS reporter,
        NULL::json AS reported
      FROM reports r LEFT JOIN users rp ON rp.id = r.reporter_id
      WHERE r.reported_id = $1
      ORDER BY r.created_at DESC
      LIMIT 100
    `, [id]),
  ]);

  res.json({
    user: {
      id: u.id,
      name: u.name,
      email: u.email,
      birthdate: u.birthdate,
      age: ageFromBirthdate(u.birthdate),
      gender: u.gender,
      interested_in: u.interested_in,
      bio: u.bio,
      interests: u.interests,
      min_age: u.min_age,
      max_age: u.max_age,
      max_distance_km: u.max_distance_km,
      has_location: u.has_location,
      is_banned: u.is_banned,
      is_demo: u.is_demo,
      banned_at: u.banned_at,
      ban_reason: u.ban_reason,
      email_verified: u.email_verified,
      created_at: u.created_at,
      last_active_at: u.last_active_at,
    },
    counts: {
      matches: u.matches,
      messages_sent: u.messages_sent,
      swipes: u.swipes,
      likes_received: u.likes_received,
      reports_made: u.reports_made,
      blocked_by: u.blocked_by,
    },
    photos: photos.rows.map((p) => ({ id: p.id, url: photoUrl(req, p.url), position: p.position })),
    reports: reports.rows.map((r) => reportRow(req, r)),
  });
}));

const banSchema = z.object({
  reason: z.string().trim().max(500, 'Sebep en fazla 500 karakter olabilir.').optional(),
});

api.post('/users/:id/ban', wrap(async (req, res) => {
  const id = idParam(req, 'Kullanıcı bulunamadı.');
  const { reason } = parse(banSchema, req.body || {});
  const ok = await inTransaction((client) => banUser(client, id, reason));
  if (!ok) throw new HttpError(404, 'Kullanıcı bulunamadı.');
  realtime.disconnectUser(id);
  res.json({ ok: true });
}));

api.post('/users/:id/unban', wrap(async (req, res) => {
  const id = idParam(req, 'Kullanıcı bulunamadı.');
  const { rowCount } = await db.query(
    'UPDATE users SET is_banned = FALSE, banned_at = NULL, ban_reason = NULL WHERE id = $1',
    [id]
  );
  if (!rowCount) throw new HttpError(404, 'Kullanıcı bulunamadı.');
  res.json({ ok: true });
}));

// ---------- Fotoğraflar ----------

api.delete('/photos/:id', wrap(async (req, res) => {
  const id = idParam(req, 'Fotoğraf bulunamadı.');
  const { rows } = await db.query('DELETE FROM photos WHERE id = $1 RETURNING url, user_id', [id]);
  if (!rows[0]) throw new HttpError(404, 'Fotoğraf bulunamadı.');
  deleteLocalPhoto(rows[0].url);
  res.json({ ok: true });
}));

api.use((req, res) => res.status(404).json({ error: 'Bulunamadı.' }));

router.use('/api', api);

// Panel dosyaları (index.html, admin.js, admin.css)
router.use(express.static(PUBLIC_DIR, { index: 'index.html' }));

// /admin altındaki bilinmeyen adresler giriş isteyen diğer yönlendiricilere düşmesin.
router.use((req, res) => res.status(404).json({ error: 'Bulunamadı.' }));

module.exports = router;
