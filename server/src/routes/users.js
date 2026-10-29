const express = require('express');
const { z } = require('zod');
const db = require('../db');
const { requireAuth } = require('../auth');
const { wrap, HttpError, parse } = require('../util');
const { photosFor, publicProfile } = require('../profiles');
const realtime = require('../realtime');

const router = express.Router();
router.use(requireAuth);

const uuid = z.string().uuid('Geçersiz kullanıcı.');

// Bir kullanıcının profili: yalnızca eşleştiğiniz kişileri görebilirsiniz.
router.get('/:id', wrap(async (req, res) => {
  const id = parse(uuid, req.params.id);
  const { rows } = await db.query(
    `SELECT u.* FROM users u
     JOIN matches m ON (m.user_a = $1 AND m.user_b = u.id) OR (m.user_b = $1 AND m.user_a = u.id)
     WHERE u.id = $2 AND NOT u.is_banned`,
    [req.userId, id]
  );
  if (!rows[0]) throw new HttpError(404, 'Kullanıcı bulunamadı.');
  const photos = await photosFor(req, [id]);
  res.json(publicProfile(rows[0], photos[id]));
}));

// Engelleme: eşleşme silinir, iki taraf birbirini bir daha görmez.
async function block(blockerId, blockedId) {
  await db.query(
    'INSERT INTO blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
    [blockerId, blockedId]
  );
  const [a, b] = [blockerId, blockedId].sort();
  const { rows } = await db.query('DELETE FROM matches WHERE user_a = $1 AND user_b = $2 RETURNING id', [a, b]);
  if (rows[0]) realtime.emitToUser(blockedId, 'match:removed', { matchId: rows[0].id });
}

router.post('/:id/block', wrap(async (req, res) => {
  const id = parse(uuid, req.params.id);
  if (id === req.userId) throw new HttpError(400, 'Kendinizi engelleyemezsiniz.');
  await block(req.userId, id);
  res.json({ ok: true });
}));

const reportSchema = z.object({
  reason: z.enum(['fake', 'inappropriate_photos', 'harassment', 'spam', 'underage', 'other'], {
    message: 'Bir şikâyet nedeni seçin.',
  }),
  details: z.string().trim().max(1000).optional().default(''),
});

// Şikâyet: kayıt altına alınır ve kişi otomatik olarak engellenir.
router.post('/:id/report', wrap(async (req, res) => {
  const id = parse(uuid, req.params.id);
  if (id === req.userId) throw new HttpError(400, 'Kendinizi şikâyet edemezsiniz.');
  const { reason, details } = parse(reportSchema, req.body);
  const exists = await db.query('SELECT 1 FROM users WHERE id = $1', [id]);
  if (!exists.rowCount) throw new HttpError(404, 'Kullanıcı bulunamadı.');
  await db.query(
    'INSERT INTO reports (reporter_id, reported_id, reason, details) VALUES ($1, $2, $3, $4)',
    [req.userId, id, reason, details]
  );
  await block(req.userId, id);
  res.status(201).json({ ok: true });
}));

module.exports = router;
