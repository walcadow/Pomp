// Anlık bildirim cihaz anahtarları (Firebase Cloud Messaging).
const express = require('express');
const { z } = require('zod');
const { requireAuth } = require('../auth');
const { wrap, parse } = require('../util');
const push = require('../push');

const router = express.Router();
router.use(requireAuth);

const tokenSchema = z.object({
  token: z.string().trim().min(10, 'Geçersiz cihaz anahtarı.').max(4096, 'Geçersiz cihaz anahtarı.'),
  platform: z.enum(['android', 'ios']).optional().default('android'),
});

const deleteSchema = z.object({
  token: z.string().trim().min(1, 'Geçersiz cihaz anahtarı.').max(4096, 'Geçersiz cihaz anahtarı.'),
});

// PUT /push/token { token, platform }  -> bu cihaz bildirimleri bu kullanıcı için alır
router.put('/token', wrap(async (req, res) => {
  const { token, platform } = parse(tokenSchema, req.body || {});
  await push.saveToken(req.userId, token, platform);
  res.json({ ok: true, enabled: push.isEnabled() });
}));

// DELETE /push/token { token }  -> çıkış yaparken bu cihaza bildirim gönderilmez
router.delete('/token', wrap(async (req, res) => {
  const { token } = parse(deleteSchema, req.body || {});
  await push.removeToken(req.userId, token);
  res.json({ ok: true });
}));

module.exports = router;
