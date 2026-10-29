const jwt = require('jsonwebtoken');
const config = require('./config');
const db = require('./db');

function signToken(userId) {
  return jwt.sign({ sub: userId }, config.jwtSecret, { expiresIn: '30d' });
}

function verifyToken(token) {
  const payload = jwt.verify(token, config.jwtSecret);
  return payload.sub;
}

// İsteğin "Authorization: Bearer <token>" başlığını kontrol eder.
async function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Giriş yapmanız gerekiyor.' });

  let userId;
  try {
    userId = verifyToken(token);
  } catch {
    return res.status(401).json({ error: 'Oturumunuzun süresi doldu, tekrar giriş yapın.' });
  }

  let rows;
  try {
    ({ rows } = await db.query(
      'UPDATE users SET last_active_at = now() WHERE id = $1 RETURNING id, is_banned',
      [userId]
    ));
  } catch (err) {
    return next(err); // veritabanı hatası sunucuyu çökertmesin
  }
  if (!rows[0]) return res.status(401).json({ error: 'Hesap bulunamadı.' });
  if (rows[0].is_banned) return res.status(403).json({ error: 'Hesabınız askıya alınmış.' });

  req.userId = userId;
  next();
}

module.exports = { signToken, verifyToken, requireAuth };
