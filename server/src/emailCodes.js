// 6 haneli e-posta kodları (e-posta doğrulama ve şifre sıfırlama).
// Kodlar veritabanında açık halde değil, gizli anahtarla özetlenmiş (HMAC-SHA256) olarak saklanır.
const crypto = require('crypto');
const db = require('./db');
const config = require('./config');
const { HttpError } = require('./util');
const { sendMail } = require('./mailer');

const CODE_TTL_MINUTES = 15;
const MAX_ATTEMPTS = 5;
const RESEND_SECONDS = 60;

function hashCode(userId, purpose, code) {
  return crypto.createHmac('sha256', config.jwtSecret).update(`${userId}:${purpose}:${code}`).digest('hex');
}

function sameHash(a, b) {
  const x = Buffer.from(a, 'hex');
  const y = Buffer.from(b, 'hex');
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

// Yeni kod üretir; aynı amaçlı eski kullanılmamış kodları geçersiz kılar.
// Son kod 60 saniyeden yeniyse 429 hatası verir.
async function issueCode(userId, purpose) {
  const { rows } = await db.query(
    `SELECT EXTRACT(EPOCH FROM (now() - created_at))::int AS age
       FROM email_codes WHERE user_id = $1 AND purpose = $2
      ORDER BY created_at DESC LIMIT 1`,
    [userId, purpose]
  );
  if (rows[0] && rows[0].age < RESEND_SECONDS) {
    const wait = RESEND_SECONDS - rows[0].age;
    throw new HttpError(429, `Yeni kod istemek için ${wait} saniye bekleyin.`);
  }

  const code = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
  await db.query(
    'UPDATE email_codes SET used_at = now() WHERE user_id = $1 AND purpose = $2 AND used_at IS NULL',
    [userId, purpose]
  );
  await db.query(
    `INSERT INTO email_codes (user_id, purpose, code_hash, expires_at)
     VALUES ($1, $2, $3, now() + make_interval(mins => $4::int))`,
    [userId, purpose, hashCode(userId, purpose, code), CODE_TTL_MINUTES]
  );
  return code;
}

// Kodu kontrol eder; doğruysa kullanıldı olarak işaretler. Yanlışsa HttpError fırlatır.
async function consumeCode(userId, purpose, code) {
  const invalid = new HttpError(400, 'Kod geçersiz ya da süresi dolmuş. Yeni kod isteyin.');
  if (!userId) throw invalid;

  const { rows } = await db.query(
    `SELECT id, code_hash, attempts FROM email_codes
      WHERE user_id = $1 AND purpose = $2 AND used_at IS NULL AND expires_at > now()
      ORDER BY created_at DESC LIMIT 1`,
    [userId, purpose]
  );
  const row = rows[0];
  if (!row) throw invalid;
  const tooMany = new HttpError(400, 'Çok fazla hatalı deneme yaptınız. Yeni kod isteyin.');
  if (row.attempts >= MAX_ATTEMPTS) throw tooMany;

  // Deneme hakkı karşılaştırmadan ÖNCE tek sorguda düşülür; böylece aynı anda gönderilen
  // çok sayıda istekle deneme sınırı aşılamaz.
  const claim = await db.query(
    `UPDATE email_codes SET attempts = attempts + 1
      WHERE id = $1 AND used_at IS NULL AND attempts < $2 RETURNING attempts`,
    [row.id, MAX_ATTEMPTS]
  );
  if (!claim.rowCount) throw tooMany;

  if (!sameHash(row.code_hash, hashCode(userId, purpose, code))) {
    const left = MAX_ATTEMPTS - claim.rows[0].attempts;
    if (left <= 0) throw tooMany;
    throw new HttpError(400, `Kod hatalı. ${left} deneme hakkınız kaldı.`);
  }

  // Aynı kodun iki kez kullanılmasını engelle.
  const used = await db.query(
    'UPDATE email_codes SET used_at = now() WHERE id = $1 AND used_at IS NULL RETURNING id',
    [row.id]
  );
  if (!used.rowCount) throw invalid;
}

// ---- E-posta metinleri ----

function codeHtml(title, intro, code, outro) {
  return `<!doctype html><html lang="tr"><body style="margin:0;padding:24px;background:#f6f4fb;font-family:Arial,Helvetica,sans-serif;color:#1f1b2e">
<div style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:16px;padding:28px">
  <div style="font-size:28px;font-weight:900;color:#6c4cf1">pomp</div>
  <h2 style="margin:16px 0 8px">${title}</h2>
  <p style="margin:0 0 16px;line-height:1.5">${intro}</p>
  <div style="font-size:40px;font-weight:800;letter-spacing:10px;text-align:center;background:#f6f4fb;border-radius:12px;padding:16px;color:#6c4cf1;font-family:Consolas,monospace">${code}</div>
  <p style="margin:16px 0 0;color:#8a8598;font-size:14px;line-height:1.5">${outro}</p>
</div></body></html>`;
}

function verifyEmail(name, code) {
  const hello = `Merhaba ${name || ''},`.replace(' ,', ',');
  return {
    subject: `Pomp doğrulama kodunuz: ${code}`,
    text:
      `${hello}\n\nPomp e-posta adresinizi doğrulamak için kodunuz:\n\n    ${code}\n\n` +
      `Kod ${CODE_TTL_MINUTES} dakika geçerlidir. Bu isteği siz yapmadıysanız bu e-postayı yok sayabilirsiniz.\n\nPomp`,
    html: codeHtml(
      'E-posta adresinizi doğrulayın',
      `${escapeHtml(hello)}<br>Pomp uygulamasına aşağıdaki kodu girin:`,
      code,
      `Kod ${CODE_TTL_MINUTES} dakika geçerlidir. Bu isteği siz yapmadıysanız bu e-postayı yok sayabilirsiniz.`
    ),
  };
}

function resetEmail(name, code) {
  const hello = `Merhaba ${name || ''},`.replace(' ,', ',');
  return {
    subject: `Pomp şifre sıfırlama kodunuz: ${code}`,
    text:
      `${hello}\n\nPomp şifrenizi sıfırlamak için kodunuz:\n\n    ${code}\n\n` +
      `Kod ${CODE_TTL_MINUTES} dakika geçerlidir. Şifre sıfırlamayı siz istemediyseniz bu e-postayı yok sayın; şifreniz değişmez.\n\nPomp`,
    html: codeHtml(
      'Şifre sıfırlama',
      `${escapeHtml(hello)}<br>Yeni şifre belirlemek için Pomp uygulamasına aşağıdaki kodu girin:`,
      code,
      `Kod ${CODE_TTL_MINUTES} dakika geçerlidir. Şifre sıfırlamayı siz istemediyseniz bu e-postayı yok sayın; şifreniz değişmez.`
    ),
  };
}

function escapeHtml(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

// Kodu üretip e-postayla gönderir. user: { id, email, name }
async function sendCode(user, purpose) {
  const code = await issueCode(user.id, purpose);
  const mail = purpose === 'reset' ? resetEmail(user.name, code) : verifyEmail(user.name, code);
  try {
    await sendMail({ to: user.email, ...mail });
  } catch (err) {
    // Gönderilemeyen kodu sil ki kullanıcı beklemeden tekrar isteyebilsin.
    await db.query(
      'DELETE FROM email_codes WHERE user_id = $1 AND purpose = $2 AND used_at IS NULL',
      [user.id, purpose]
    );
    throw err;
  }
}

module.exports = { issueCode, consumeCode, sendCode, CODE_TTL_MINUTES, RESEND_SECONDS };
