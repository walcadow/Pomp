const express = require('express');
const db = require('../db');
const { requireAuth } = require('../auth');
const { wrap } = require('../util');
const { photosFor, publicProfile } = require('../profiles');
const { getMatchForUser, toMessage, sendMessage, markRead } = require('../chat');
const realtime = require('../realtime');

const router = express.Router();
router.use(requireAuth);

// GET /matches -> eşleşmeler, son mesaj ve okunmamış mesaj sayısıyla
router.get('/', wrap(async (req, res) => {
  const { rows } = await db.query(
    `SELECT m.id AS match_id, m.created_at AS match_created_at, u.*,
            lm.id AS lm_id, lm.match_id AS lm_match_id, lm.sender_id AS lm_sender_id,
            lm.body AS lm_body, lm.created_at AS lm_created_at, lm.read_at AS lm_read_at,
            (SELECT COUNT(*)::int FROM messages x
              WHERE x.match_id = m.id AND x.sender_id <> $1 AND x.read_at IS NULL) AS unread
     FROM matches m
     JOIN users u ON u.id = CASE WHEN m.user_a = $1 THEN m.user_b ELSE m.user_a END
     LEFT JOIN LATERAL (
       SELECT * FROM messages WHERE match_id = m.id ORDER BY created_at DESC LIMIT 1
     ) lm ON TRUE
     WHERE (m.user_a = $1 OR m.user_b = $1) AND NOT u.is_banned
     ORDER BY COALESCE(lm.created_at, m.created_at) DESC`,
    [req.userId]
  );

  const photos = await photosFor(req, rows.map((r) => r.id));
  res.json(rows.map((r) => ({
    id: r.match_id,
    createdAt: r.match_created_at,
    user: publicProfile(r, photos[r.id]),
    unread: r.unread,
    lastMessage: r.lm_id
      ? toMessage({ id: r.lm_id, match_id: r.lm_match_id, sender_id: r.lm_sender_id, body: r.lm_body, created_at: r.lm_created_at, read_at: r.lm_read_at })
      : null,
  })));
}));

// GET /matches/:id/messages?before=<tarih> -> en yeniden eskiye 50 mesaj
router.get('/:id/messages', wrap(async (req, res) => {
  const match = await getMatchForUser(req.params.id, req.userId);
  const before = req.query.before && !Number.isNaN(Date.parse(req.query.before)) ? req.query.before : null;
  const { rows } = await db.query(
    `SELECT * FROM messages
     WHERE match_id = $1 AND ($2::timestamptz IS NULL OR created_at < $2)
     ORDER BY created_at DESC LIMIT 50`,
    [match.id, before]
  );
  res.json(rows.map(toMessage));
}));

router.post('/:id/messages', wrap(async (req, res) => {
  res.status(201).json(await sendMessage(req.userId, req.params.id, req.body && req.body.body));
}));

router.post('/:id/read', wrap(async (req, res) => {
  await markRead(req.userId, req.params.id);
  res.json({ ok: true });
}));

// DELETE /matches/:id -> eşleşmeyi kaldır (sohbet de silinir)
router.delete('/:id', wrap(async (req, res) => {
  const match = await getMatchForUser(req.params.id, req.userId);
  await db.query('DELETE FROM matches WHERE id = $1', [match.id]);
  realtime.emitToUser(match.other, 'match:removed', { matchId: match.id });
  res.json({ ok: true });
}));

module.exports = router;
