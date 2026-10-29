const express = require('express');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const { z } = require('zod');
const db = require('../db');
const config = require('../config');
const { signToken, requireAuth } = require('../auth');
const { wrap, HttpError, ageFromBirthdate, parse } = require('../util');
const { loadOwnProfile } = require('../profiles');
const { sendCode, consumeCode } = require('../emailCodes');

const router = express.Router();

// Kaba kuvvet saldırılarına karşı: 15 dakikada en fazla 20 deneme.
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla deneme yaptınız. Biraz sonra tekrar deneyin.' },
});

const genders = ['male', 'female', 'other'];

const registerSchema = z.object({
  email: z.string().trim().toLowerCase().email('Geçerli bir e-posta adresi girin.'),
  password: z.string().min(8, 'Şifre en az 8 karakter olmalı.').max(100),
  name: z.string().trim().min(2, 'İsim en az 2 karakter olmalı.').max(40),
  birthdate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Doğum tarihi YYYY-AA-GG biçiminde olmalı.'),
  gender: z.enum(genders, { message: 'Cinsiyet seçin.' }),
  interestedIn: z.array(z.enum(genders)).min(1, 'Kimlerle tanışmak istediğinizi seçin.'),
  acceptedTerms: z.literal(true, { message: 'Kullanım koşullarını ve aydınlatma metnini onaylamanız gerekiyor.' }),
});

router.post('/register', limiter, wrap(async (req, res) => {
  const data = parse(registerSchema, req.body);

  if (Number.isNaN(Date.parse(data.birthdate))) throw new HttpError(400, 'Geçersiz doğum tarihi.');
  const age = ageFromBirthdate(data.birthdate);
  if (age < config.minAge) throw new HttpError(400, `Pomp'u kullanmak için en az ${config.minAge} yaşında olmalısınız.`);
  if (age > 120) throw new HttpError(400, 'Geçersiz doğum tarihi.');

  const exists = await db.query('SELECT 1 FROM users WHERE email = $1', [data.email]);
  if (exists.rowCount) throw new HttpError(409, 'Bu e-posta ile zaten bir hesap var.');

  const hash = await bcrypt.hash(data.password, 10);
  const { rows } = await db.query(
    `INSERT INTO users (email, password_hash, name, birthdate, gender, interested_in)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
    [data.email, hash, data.name, data.birthdate, data.gender, data.interestedIn]
  );
  const userId = rows[0].id;
  // Doğrulama kodunu arka planda gönder; e-posta gönderilemezse kayıt yine başarılı sayılır.
  sendCode({ id: userId, email: data.email, name: data.name }, 'verify').catch((err) =>
    console.error('Doğrulama e-postası gönderilemedi:', err.message)
  );
  res.status(201).json({ token: signToken(userId), user: await loadOwnProfile(req, userId) });
}));

const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email('Geçerli bir e-posta adresi girin.'),
  password: z.string().min(1, 'Şifrenizi girin.'),
});

router.post('/login', limiter, wrap(async (req, res) => {
  const data = parse(loginSchema, req.body);
  const { rows } = await db.query('SELECT id, password_hash, is_banned FROM users WHERE email = $1', [data.email]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(data.password, user.password_hash))) {
    throw new HttpError(401, 'E-posta veya şifre hatalı.');
  }
  if (user.is_banned) throw new HttpError(403, 'Hesabınız askıya alınmış.');
  res.json({ token: signToken(user.id), user: await loadOwnProfile(req, user.id) });
}));

// ---- Şifre sıfırlama ve e-posta doğrulama (6 haneli kodlar) ----

// Kod isteme/deneme uçları için ayrı sınır: 15 dakikada en fazla 30 istek.
const codeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Çok fazla deneme yaptınız. Biraz sonra tekrar deneyin.' },
});

const emailField = z.string().trim().toLowerCase().email('Geçerli bir e-posta adresi girin.');
const codeField = z.string().trim().regex(/^\d{6}$/, 'Kod 6 haneli olmalı.');

function mailFailed(res) {
  return res.status(502).json({ error: 'E-posta gönderilemedi. Biraz sonra tekrar deneyin.' });
}

router.post('/forgot', codeLimiter, wrap(async (req, res) => {
  const { email } = parse(z.object({ email: emailField }), req.body);
  const { rows } = await db.query('SELECT id, email, name, is_banned FROM users WHERE email = $1', [email]);
  const user = rows[0];
  if (user && !user.is_banned) {
    // Arka planda gönder: yanıt süresi e-postanın kayıtlı olup olmadığını belli etmesin.
    // Bekleme süresi (429) dahil hatalar sessizce yutulur.
    sendCode(user, 'reset').catch((err) => {
      if (err.status !== 429) console.error('Şifre sıfırlama e-postası gönderilemedi:', err.message);
    });
  }
  res.json({
    ok: true,
    message: 'Bu e-posta ile kayıtlı bir hesap varsa şifre sıfırlama kodu gönderildi. Gelen kutunuzu (ve spam klasörünü) kontrol edin.',
  });
}));

const resetSchema = z.object({
  email: emailField,
  code: codeField,
  password: z.string().min(8, 'Şifre en az 8 karakter olmalı.').max(100),
});

router.post('/reset', codeLimiter, wrap(async (req, res) => {
  const data = parse(resetSchema, req.body);
  const { rows } = await db.query('SELECT id, is_banned FROM users WHERE email = $1', [data.email]);
  const user = rows[0];
  await consumeCode(user?.id, 'reset', data.code);
  if (user.is_banned) throw new HttpError(403, 'Hesabınız askıya alınmış.');

  const hash = await bcrypt.hash(data.password, 10);
  // Kodu e-postadan aldığı için adres de doğrulanmış sayılır.
  await db.query('UPDATE users SET password_hash = $2, email_verified = TRUE WHERE id = $1', [user.id, hash]);
  res.json({ token: signToken(user.id), user: await loadOwnProfile(req, user.id) });
}));

router.post('/verify/send', requireAuth, codeLimiter, wrap(async (req, res) => {
  const { rows } = await db.query('SELECT id, email, name, email_verified FROM users WHERE id = $1', [req.userId]);
  const user = rows[0];
  if (user.email_verified) throw new HttpError(400, 'E-posta adresiniz zaten doğrulanmış.');
  try {
    await sendCode(user, 'verify');
  } catch (err) {
    if (err.status && err.status < 500) throw err;
    console.error('Doğrulama e-postası gönderilemedi:', err.message);
    return mailFailed(res);
  }
  res.json({ ok: true, message: `Doğrulama kodu ${user.email} adresine gönderildi.` });
}));

router.post('/verify', requireAuth, codeLimiter, wrap(async (req, res) => {
  const { code } = parse(z.object({ code: codeField }), req.body);
  const { rows } = await db.query('SELECT email_verified FROM users WHERE id = $1', [req.userId]);
  if (!rows[0].email_verified) {
    await consumeCode(req.userId, 'verify', code);
    await db.query('UPDATE users SET email_verified = TRUE WHERE id = $1', [req.userId]);
  }
  res.json(await loadOwnProfile(req, req.userId));
}));

module.exports = router;
