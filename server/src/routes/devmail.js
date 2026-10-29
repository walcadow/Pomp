// Geliştirme ortamında gönderilen (aslında gönderilmeyen) e-postaları gösteren sayfa.
// Yalnızca NODE_ENV !== 'production' iken çalışır; yayında 404 döner.
const express = require('express');
const { recentEmails, smtpEnabled } = require('../mailer');

const router = express.Router();

const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

router.get('/emails', (req, res) => {
  // next() burada giriş isteyen keşfet yönlendiricisine düşerdi (401); doğrudan 404 dön.
  if (process.env.NODE_ENV === 'production') return res.status(404).json({ error: 'Bulunamadı.' });

  const emails = recentEmails();
  const items = emails
    .map((m) => {
      const code = (String(m.text || '').match(/\b\d{6}\b/) || [])[0];
      return `
      <div class="mail">
        <div class="meta"><b>${esc(m.to)}</b> · ${esc(m.sentAt.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul' }))}</div>
        <div class="subject">${esc(m.subject)}</div>
        ${code ? `<div class="code">${esc(code)}</div>` : ''}
        <pre>${esc(m.text)}</pre>
      </div>`;
    })
    .join('');

  const note = smtpEnabled()
    ? '<p class="warn">SMTP ayarlı: e-postalar gerçekten gönderiliyor, burada görünmezler.</p>'
    : '';

  res.set('Cache-Control', 'no-store');
  res.type('html').send(`<!doctype html>
<html lang="tr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="10">
<title>Pomp - Test e-postaları</title>
<style>
  body { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; background:#f6f4fb; color:#1f1b2e; margin:0; padding:24px; }
  h1 { margin:0 0 4px; color:#6c4cf1; }
  .hint { color:#8a8598; margin:0 0 20px; }
  .warn { background:#fff3cd; padding:10px 14px; border-radius:10px; }
  .mail { background:#fff; border-radius:14px; padding:16px 20px; margin-bottom:14px; box-shadow:0 1px 4px rgba(0,0,0,.06); }
  .meta { color:#8a8598; font-size:14px; }
  .subject { font-weight:700; font-size:18px; margin:6px 0; }
  .code { font-size:44px; font-weight:800; letter-spacing:10px; color:#6c4cf1; margin:8px 0; font-family: ui-monospace, Consolas, monospace; }
  pre { white-space:pre-wrap; color:#555; font-size:13px; margin:8px 0 0; }
  .empty { color:#8a8598; }
</style></head><body>
<h1>Test e-postaları</h1>
<p class="hint">Geliştirme modunda e-postalar gönderilmez, burada görünür (en yeni üstte, son 50). Sayfa 10 saniyede bir yenilenir.</p>
${note}
${items || '<p class="empty">Henüz e-posta yok.</p>'}
</body></html>`);
});

module.exports = router;
