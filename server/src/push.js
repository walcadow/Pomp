// Anlık bildirimler (Firebase Cloud Messaging).
// Firebase ayarlanmamışsa (hizmet hesabı dosyası yoksa) her şey sessizce devre dışı kalır;
// uygulama bildirimler olmadan eskisi gibi çalışmaya devam eder.
//
// Hizmet hesabı şu sırayla aranır:
//   1) FIREBASE_SERVICE_ACCOUNT_JSON  : JSON içeriğinin kendisi
//   2) FIREBASE_SERVICE_ACCOUNT_FILE  : JSON dosyasının yolu
//   3) server/firebase-service-account.json (varsa)
const fs = require('fs');
const path = require('path');
const db = require('./db');

const DEFAULT_FILE = path.join(__dirname, '..', 'firebase-service-account.json');
const ANDROID_CHANNEL_ID = 'pomp_default';
// Bu hatalar cihaz anahtarının artık geçersiz olduğunu gösterir; anahtar silinir.
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

let messaging = null; // hazırsa firebase-admin messaging nesnesi
let initialized = false;

function loadServiceAccount() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
  }
  const file = process.env.FIREBASE_SERVICE_ACCOUNT_FILE || DEFAULT_FILE;
  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) return null;
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

// Firebase'i ilk ihtiyaç anında bir kez hazırlar. Hazır değilse null döner.
function getMessaging() {
  if (initialized) return messaging;
  initialized = true;
  try {
    const account = loadServiceAccount();
    if (!account) {
      console.log('Bildirimler kapalı: Firebase hizmet hesabı bulunamadı (PUSH_KURULUM.md dosyasına bakın).');
      return null;
    }
    let admin;
    try {
      admin = require('firebase-admin');
    } catch {
      console.warn('Bildirimler kapalı: "firebase-admin" paketi kurulu değil.');
      return null;
    }
    const app = admin.apps.length
      ? admin.app()
      : admin.initializeApp({ credential: admin.credential.cert(account) });
    messaging = admin.messaging(app);
    console.log(`Bildirimler açık (Firebase projesi: ${account.project_id || 'bilinmiyor'}).`);
  } catch (err) {
    console.warn('Bildirimler kapalı: Firebase başlatılamadı:', err.message);
    messaging = null;
  }
  return messaging;
}

function isEnabled() {
  return Boolean(getMessaging());
}

// FCM "data" alanındaki tüm değerler metin olmalı.
function stringifyData(data) {
  const out = {};
  for (const [k, v] of Object.entries(data || {})) {
    if (v !== undefined && v !== null) out[k] = String(v);
  }
  return out;
}

/**
 * Kullanıcının tüm cihazlarına bildirim gönderir. Asla hata fırlatmaz.
 * @param {string} userId
 * @param {{title: string, body: string, data?: object}} payload
 */
async function notifyUser(userId, { title, body, data } = {}) {
  try {
    const m = getMessaging();
    if (!m || !userId) return;

    const { rows } = await db.query('SELECT token FROM push_tokens WHERE user_id = $1', [userId]);
    if (!rows.length) return;
    const tokens = rows.map((r) => r.token);
    const strData = stringifyData(data);

    const dead = [];
    // Tek seferde en fazla 500 cihaz anahtarı gönderilebilir.
    for (let i = 0; i < tokens.length; i += 500) {
      const batch = tokens.slice(i, i + 500);
      const res = await m.sendEachForMulticast({
        tokens: batch,
        notification: { title: String(title || ''), body: String(body || '') },
        data: strData,
        android: {
          priority: 'high',
          notification: {
            channelId: ANDROID_CHANNEL_ID,
            sound: 'default',
            // Aynı sohbetten gelen bildirimler üst üste biner.
            ...(strData.matchId ? { tag: `${strData.type || 'pomp'}-${strData.matchId}` } : {}),
          },
        },
        apns: { payload: { aps: { sound: 'default' } } },
      });
      res.responses.forEach((r, idx) => {
        if (!r.success && r.error && DEAD_TOKEN_CODES.has(r.error.code)) dead.push(batch[idx]);
      });
    }

    if (dead.length) {
      await db.query('DELETE FROM push_tokens WHERE token = ANY($1::text[])', [dead]);
    }
  } catch (err) {
    console.warn('Bildirim gönderilemedi:', err.message);
  }
}

// Cihaz anahtarını bu kullanıcıya kaydeder (başka kullanıcıdaysa bu kullanıcıya geçer).
async function saveToken(userId, token, platform) {
  await db.query(
    `INSERT INTO push_tokens (token, user_id, platform, updated_at) VALUES ($1, $2, $3, now())
     ON CONFLICT (token) DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, updated_at = now()`,
    [token, userId, platform]
  );
}

async function removeToken(userId, token) {
  await db.query('DELETE FROM push_tokens WHERE token = $1 AND user_id = $2', [token, userId]);
}

module.exports = { notifyUser, saveToken, removeToken, isEnabled };
