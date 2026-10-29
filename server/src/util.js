const config = require('./config');

// async route'lardaki hataları Express'in hata yakalayıcısına iletir.
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function ageFromBirthdate(birthdate) {
  const b = new Date(birthdate);
  const now = new Date();
  let age = now.getUTCFullYear() - b.getUTCFullYear();
  const m = now.getUTCMonth() - b.getUTCMonth();
  if (m < 0 || (m === 0 && now.getUTCDate() < b.getUTCDate())) age--;
  return age;
}

// Fotoğraf yollarını tam adrese çevirir (örn. /uploads/x.jpg -> http://sunucu/uploads/x.jpg).
function photoUrl(req, url) {
  if (/^https?:\/\//.test(url)) return url;
  const base = config.publicUrl || `${req.protocol}://${req.get('host')}`;
  return base + url;
}

// Zod doğrulama hatalarını okunur bir mesaja çevirir.
function parse(schema, data) {
  const result = schema.safeParse(data);
  if (!result.success) {
    const first = result.error.issues[0];
    throw new HttpError(400, first.message || 'Geçersiz bilgi.');
  }
  return result.data;
}

module.exports = { wrap, HttpError, ageFromBirthdate, photoUrl, parse };
