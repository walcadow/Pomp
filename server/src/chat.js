// Sohbet işlemleri: hem REST uçları hem de anlık bağlantı (socket) bunları kullanır.
const db = require('./db');
const { HttpError } = require('./util');
const realtime = require('./realtime');

const MAX_LEN = 2000;

// Eşleşme bu kullanıcıya mı ait? Değilse hata fırlatır. Karşı tarafın id'sini döndürür.
async function getMatchForUser(matchId, userId) {
  if (!/^[0-9a-f-]{36}$/i.test(String(matchId))) throw new HttpError(404, 'Eşleşme bulunamadı.');
  const { rows } = await db.query(
    `SELECT id, CASE WHEN user_a = $2 THEN user_b ELSE user_a END AS other
     FROM matches WHERE id = $1 AND (user_a = $2 OR user_b = $2)`,
    [matchId, userId]
  );
  if (!rows[0]) throw new HttpError(404, 'Eşleşme bulunamadı.');
  return rows[0];
}

function toMessage(row) {
  return {
    id: row.id,
    matchId: row.match_id,
    senderId: row.sender_id,
    body: row.body,
    createdAt: row.created_at,
    readAt: row.read_at,
  };
}

async function sendMessage(userId, matchId, rawBody) {
  const body = String(rawBody || '').trim();
  if (!body) throw new HttpError(400, 'Boş mesaj gönderilemez.');
  if (body.length > MAX_LEN) throw new HttpError(400, `Mesaj en fazla ${MAX_LEN} karakter olabilir.`);

  const match = await getMatchForUser(matchId, userId);
  const { rows } = await db.query(
    'INSERT INTO messages (match_id, sender_id, body) VALUES ($1, $2, $3) RETURNING *',
    [match.id, userId, body]
  );
  const message = toMessage(rows[0]);
  realtime.emitToUser(match.other, 'message:new', message);
  realtime.emitToUser(userId, 'message:new', message); // kullanıcının diğer cihazları için
  maybeDemoReply(match, userId);
  return message;
}

// Demo kullanıcılar, sohbeti deneyebilmeniz için kısa bir süre sonra otomatik cevap verir.
const DEMO_REPLIES = [
  'Merhaba! 😊 Nasılsın?',
  'Haha, güzel soru. Sen ne düşünüyorsun?',
  'Bu hafta sonu ne yapıyorsun?',
  'Profilindeki fotoğraflar çok güzel!',
  'Ben de tam bunu düşünüyordum 😄',
];

async function maybeDemoReply(match, senderId) {
  try {
    const { rows } = await db.query('SELECT is_demo FROM users WHERE id = $1', [match.other]);
    if (!rows[0] || !rows[0].is_demo || process.env.DEMO_REPLIES === 'false') return;
    setTimeout(async () => {
      try {
        realtime.emitToUser(senderId, 'typing', { matchId: match.id, userId: match.other });
        await new Promise((r) => setTimeout(r, 1200));
        await db.query('UPDATE messages SET read_at = now() WHERE match_id = $1 AND sender_id = $2 AND read_at IS NULL', [match.id, senderId]);
        realtime.emitToUser(senderId, 'message:read', { matchId: match.id, readerId: match.other });
        const body = DEMO_REPLIES[Math.floor(Math.random() * DEMO_REPLIES.length)];
        const { rows: msg } = await db.query(
          'INSERT INTO messages (match_id, sender_id, body) VALUES ($1, $2, $3) RETURNING *',
          [match.id, match.other, body]
        );
        realtime.emitToUser(senderId, 'message:new', toMessage(msg[0]));
      } catch {
        /* eşleşme bu arada silinmiş olabilir */
      }
    }, 800);
  } catch {
    /* yok say */
  }
}

async function markRead(userId, matchId) {
  const match = await getMatchForUser(matchId, userId);
  const { rowCount } = await db.query(
    'UPDATE messages SET read_at = now() WHERE match_id = $1 AND sender_id = $2 AND read_at IS NULL',
    [match.id, match.other]
  );
  if (rowCount) realtime.emitToUser(match.other, 'message:read', { matchId: match.id, readerId: userId });
  return rowCount;
}

module.exports = { getMatchForUser, toMessage, sendMessage, markRead };
