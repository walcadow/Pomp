// E-posta gönderimi.
// - .env dosyasında SMTP_HOST ayarlıysa gerçek e-posta gönderilir (nodemailer ile).
// - Ayarlı değilse (geliştirme) e-posta konsola yazılır ve son 50 e-posta bellekte tutulur;
//   bunlar geliştirme ortamında http://localhost:3000/dev/emails adresinden görülebilir.

const MAX_KEPT = 50;
const recent = []; // en yeni başta

let transport = null;
function getTransport() {
  if (transport) return transport;
  let nodemailer;
  try {
    // Yalnızca SMTP kullanılıyorsa gerekir.
    nodemailer = require('nodemailer');
  } catch {
    throw new Error('SMTP_HOST ayarlı ama "nodemailer" paketi yüklü değil. Sunucu klasöründe "npm install nodemailer" çalıştırın.');
  }
  const port = Number(process.env.SMTP_PORT || 587);
  const secure = process.env.SMTP_SECURE ? process.env.SMTP_SECURE === 'true' : port === 465;
  transport = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port,
    secure,
    auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS || '' } : undefined,
  });
  return transport;
}

function smtpEnabled() {
  return Boolean(process.env.SMTP_HOST);
}

async function sendMail({ to, subject, text, html }) {
  if (smtpEnabled()) {
    const from = process.env.SMTP_FROM || process.env.SMTP_USER || 'Pomp <no-reply@pomp.app>';
    await getTransport().sendMail({ from, to, subject, text, html });
    return;
  }

  // Geliştirme: gerçek gönderim yok, konsola yaz ve bellekte sakla.
  recent.unshift({ to, subject, text, html, sentAt: new Date() });
  if (recent.length > MAX_KEPT) recent.length = MAX_KEPT;
  console.log(
    [
      '',
      '==================== E-POSTA (gönderilmedi, geliştirme modu) ====================',
      `Kime : ${to}`,
      `Konu : ${subject}`,
      '',
      text,
      '================================================================================',
      '',
    ].join('\n')
  );
}

function recentEmails() {
  return recent.slice();
}

module.exports = { sendMail, recentEmails, smtpEnabled };
