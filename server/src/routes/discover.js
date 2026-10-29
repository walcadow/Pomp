const express = require('express');
const { z } = require('zod');
const db = require('../db');
const config = require('../config');
const { requireAuth } = require('../auth');
const { wrap, HttpError, parse } = require('../util');
const { photosFor, publicProfile } = require('../profiles');
const realtime = require('../realtime');

const router = express.Router();
router.use(requireAuth);

// İki nokta arasındaki kuş uçuşu mesafe (km), "haversine" formülüyle.
const DISTANCE_SQL = `
  6371 * 2 * asin(sqrt(
    power(sin(radians(u.lat - me.lat) / 2), 2) +
    cos(radians(me.lat)) * cos(radians(u.lat)) * power(sin(radians(u.lng - me.lng) / 2), 2)
  ))`;

// GET /discover?exclude=id1,id2  -> kaydırılacak profil kartları
router.get('/discover', wrap(async (req, res) => {
  const me = (await db.query('SELECT lat, lng FROM users WHERE id = $1', [req.userId])).rows[0];
  if (me.lat == null || me.lng == null) {
    throw new HttpError(409, 'Yakınınızdaki kişileri görebilmek için konum izni vermeniz gerekiyor.');
  }

  const uuid = /^[0-9a-f-]{36}$/i;
  const exclude = String(req.query.exclude || '')
    .split(',')
    .filter((id) => uuid.test(id))
    .slice(0, 100);

  const { rows } = await db.query(
    `SELECT * FROM (
       SELECT u.*, ${DISTANCE_SQL} AS distance_km, me.max_distance_km AS my_max
       FROM users u, (SELECT * FROM users WHERE id = $1) me
       WHERE u.id <> me.id
         AND NOT u.is_banned
         AND u.lat IS NOT NULL
         AND u.gender = ANY(me.interested_in)
         AND me.gender = ANY(u.interested_in)
         AND date_part('year', age(u.birthdate)) BETWEEN me.min_age AND me.max_age
         AND ($3 OR EXISTS (SELECT 1 FROM photos p WHERE p.user_id = u.id))
         AND NOT EXISTS (SELECT 1 FROM swipes s WHERE s.swiper_id = me.id AND s.target_id = u.id)
         AND NOT EXISTS (
           SELECT 1 FROM blocks b
           WHERE (b.blocker_id = me.id AND b.blocked_id = u.id)
              OR (b.blocker_id = u.id AND b.blocked_id = me.id)
         )
         AND NOT (u.id = ANY($2::uuid[]))
     ) candidates
     WHERE distance_km <= my_max
     ORDER BY last_active_at DESC, distance_km ASC
     LIMIT 20`,
    [req.userId, exclude, config.allowNoPhoto]
  );

  const photos = await photosFor(req, rows.map((r) => r.id));
  res.json(rows.map((r) => publicProfile(r, photos[r.id])));
}));

const swipeSchema = z.object({
  targetId: z.string().uuid('Geçersiz kullanıcı.'),
  liked: z.boolean(),
});

// POST /swipes { targetId, liked }  -> { matched, match? }
router.post('/swipes', wrap(async (req, res) => {
  const { targetId, liked } = parse(swipeSchema, req.body);
  if (targetId === req.userId) throw new HttpError(400, 'Kendinizi beğenemezsiniz.');

  const target = (await db.query('SELECT id FROM users WHERE id = $1 AND NOT is_banned', [targetId])).rows[0];
  if (!target) throw new HttpError(404, 'Kullanıcı bulunamadı.');

  await db.query(
    `INSERT INTO swipes (swiper_id, target_id, liked) VALUES ($1, $2, $3)
     ON CONFLICT (swiper_id, target_id) DO NOTHING`,
    [req.userId, targetId, liked]
  );

  if (!liked) return res.json({ matched: false });

  // Karşı taraf da beğenmiş mi? Engelleme varsa eşleşme olmaz.
  const mutual = await db.query(
    `SELECT 1 FROM swipes WHERE swiper_id = $1 AND target_id = $2 AND liked
       AND NOT EXISTS (
         SELECT 1 FROM blocks
         WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1)
       )`,
    [targetId, req.userId]
  );
  if (!mutual.rowCount) return res.json({ matched: false });

  const [a, b] = [req.userId, targetId].sort();
  const inserted = await db.query(
    `INSERT INTO matches (user_a, user_b) VALUES ($1, $2)
     ON CONFLICT (user_a, user_b) DO NOTHING RETURNING id, created_at`,
    [a, b]
  );
  const match = inserted.rows[0]
    || (await db.query('SELECT id, created_at FROM matches WHERE user_a = $1 AND user_b = $2', [a, b])).rows[0];

  const { rows: users } = await db.query('SELECT * FROM users WHERE id = ANY($1::uuid[])', [[req.userId, targetId]]);
  const photos = await photosFor(req, [req.userId, targetId]);
  const byId = Object.fromEntries(users.map((u) => [u.id, publicProfile(u, photos[u.id])]));

  const forMe = { id: match.id, createdAt: match.created_at, user: byId[targetId], lastMessage: null, unread: 0 };
  const forThem = { id: match.id, createdAt: match.created_at, user: byId[req.userId], lastMessage: null, unread: 0 };

  if (inserted.rowCount) realtime.emitToUser(targetId, 'match:new', forThem);
  res.json({ matched: true, match: forMe });
}));

module.exports = router;
