const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const multer = require('multer');
const { z } = require('zod');
const db = require('../db');
const config = require('../config');
const { requireAuth } = require('../auth');
const { wrap, HttpError, parse } = require('../util');
const { loadOwnProfile } = require('../profiles');
const realtime = require('../realtime');

const router = express.Router();
router.use(requireAuth);

fs.mkdirSync(config.uploadDir, { recursive: true });

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024, files: 1 },
});

// Dosyanın gerçekten bir resim olup olmadığını ilk baytlarına bakarak anlar.
function detectImageType(buf) {
  if (buf.length < 12) return null;
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (buf.slice(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'png';
  if (buf.slice(0, 4).toString() === 'RIFF' && buf.slice(8, 12).toString() === 'WEBP') return 'webp';
  return null;
}

function deleteLocalPhoto(url) {
  if (!url.startsWith('/uploads/')) return;
  const file = path.join(config.uploadDir, path.basename(url));
  fs.promises.unlink(file).catch(() => {});
}

router.get('/', wrap(async (req, res) => {
  res.json(await loadOwnProfile(req, req.userId));
}));

const genders = ['male', 'female', 'other'];
const updateSchema = z.object({
  name: z.string().trim().min(2, 'İsim en az 2 karakter olmalı.').max(40).optional(),
  bio: z.string().trim().max(500, 'Hakkımda en fazla 500 karakter olabilir.').optional(),
  interests: z.array(z.string().trim().min(1).max(30)).max(10, 'En fazla 10 ilgi alanı seçebilirsiniz.').optional(),
  gender: z.enum(genders).optional(),
  interestedIn: z.array(z.enum(genders)).min(1, 'En az bir seçim yapın.').optional(),
  minAge: z.number().int().min(18).max(99).optional(),
  maxAge: z.number().int().min(18).max(99).optional(),
  maxDistanceKm: z.number().int().min(1).max(500).optional(),
}).strict();

router.patch('/', wrap(async (req, res) => {
  const data = parse(updateSchema, req.body);
  const columns = {
    name: 'name', bio: 'bio', interests: 'interests', gender: 'gender',
    interestedIn: 'interested_in', minAge: 'min_age', maxAge: 'max_age', maxDistanceKm: 'max_distance_km',
  };
  const sets = [];
  const values = [];
  for (const [key, col] of Object.entries(columns)) {
    if (data[key] !== undefined) {
      values.push(data[key]);
      sets.push(`${col} = $${values.length}`);
    }
  }
  if (sets.length) {
    values.push(req.userId);
    await db.query(`UPDATE users SET ${sets.join(', ')} WHERE id = $${values.length}`, values);
  }
  const profile = await loadOwnProfile(req, req.userId);
  if (profile.minAge > profile.maxAge) {
    await db.query('UPDATE users SET max_age = min_age WHERE id = $1', [req.userId]);
    profile.maxAge = profile.minAge;
  }
  res.json(profile);
}));

const locationSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

router.put('/location', wrap(async (req, res) => {
  const { lat, lng } = parse(locationSchema, req.body);
  await db.query(
    'UPDATE users SET lat = $1, lng = $2, location_updated_at = now() WHERE id = $3',
    [lat, lng, req.userId]
  );
  res.json({ ok: true });
}));

router.post('/photos', upload.single('photo'), wrap(async (req, res) => {
  if (!req.file) throw new HttpError(400, 'Bir fotoğraf seçin.');
  const type = detectImageType(req.file.buffer);
  if (!type) throw new HttpError(400, 'Yalnızca JPG, PNG veya WEBP fotoğraf yükleyebilirsiniz.');

  const { rows } = await db.query('SELECT COUNT(*)::int AS n, COALESCE(MAX(position), -1) AS maxpos FROM photos WHERE user_id = $1', [req.userId]);
  if (rows[0].n >= config.maxPhotos) throw new HttpError(400, `En fazla ${config.maxPhotos} fotoğraf ekleyebilirsiniz.`);

  const filename = `${crypto.randomUUID()}.${type}`;
  await fs.promises.writeFile(path.join(config.uploadDir, filename), req.file.buffer);
  await db.query(
    'INSERT INTO photos (user_id, url, position) VALUES ($1, $2, $3)',
    [req.userId, `/uploads/${filename}`, rows[0].maxpos + 1]
  );
  res.status(201).json(await loadOwnProfile(req, req.userId));
}));

router.delete('/photos/:photoId', wrap(async (req, res) => {
  const { rows } = await db.query(
    'DELETE FROM photos WHERE id = $1 AND user_id = $2 RETURNING url',
    [req.params.photoId, req.userId]
  );
  if (!rows[0]) throw new HttpError(404, 'Fotoğraf bulunamadı.');
  deleteLocalPhoto(rows[0].url);
  res.json(await loadOwnProfile(req, req.userId));
}));

// Fotoğraf sırasını değiştirir: { photoIds: [ilk, ikinci, ...] }
router.put('/photos/order', wrap(async (req, res) => {
  const { photoIds } = parse(z.object({ photoIds: z.array(z.string().uuid()).max(config.maxPhotos) }), req.body);
  for (let i = 0; i < photoIds.length; i++) {
    await db.query('UPDATE photos SET position = $1 WHERE id = $2 AND user_id = $3', [i, photoIds[i], req.userId]);
  }
  res.json(await loadOwnProfile(req, req.userId));
}));

// Hesabı ve tüm verileri kalıcı olarak siler (KVKK: silme hakkı).
router.delete('/', wrap(async (req, res) => {
  const { rows: photos } = await db.query('SELECT url FROM photos WHERE user_id = $1', [req.userId]);
  const { rows: matches } = await db.query(
    'SELECT id, CASE WHEN user_a = $1 THEN user_b ELSE user_a END AS other FROM matches WHERE user_a = $1 OR user_b = $1',
    [req.userId]
  );
  await db.query('DELETE FROM users WHERE id = $1', [req.userId]);
  photos.forEach((p) => deleteLocalPhoto(p.url));
  for (const m of matches) realtime.emitToUser(m.other, 'match:removed', { matchId: m.id });
  realtime.disconnectUser(req.userId);
  res.json({ ok: true });
}));

module.exports = router;
