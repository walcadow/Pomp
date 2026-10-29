// Deneme için sahte (demo) kullanıcılar oluşturur.
// Kullanım:  npm run seed
//            npm run seed -- --lat 40.99 --lng 29.02   (belirli bir konumun çevresine)
// Konum verilmezse, uygulamadan en son giriş yapan gerçek kullanıcının çevresine yerleştirilir.
// Demo kullanıcıların yarısı sizi önceden "beğenmiş" olur; sağa kaydırınca hemen eşleşirsiniz.

const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const db = require('./db');
const migrate = require('./migrate');

const DEMO = [
  ['Elif', 'female', 24, 'Kahve, kitap ve uzun yürüyüşler ☕📚', ['Kitap', 'Kahve', 'Yürüyüş']],
  ['Mert', 'male', 27, 'Hafta sonları dağdayım, hafta içi kod yazıyorum.', ['Kamp', 'Yazılım', 'Fotoğraf']],
  ['Zeynep', 'female', 29, 'Yeni restoranlar keşfetmeyi seviyorum. Önerin var mı?', ['Yemek', 'Seyahat', 'Sinema']],
  ['Can', 'male', 25, 'Gitar çalarım, kötü espri yaparım 🎸', ['Müzik', 'Konser', 'Futbol']],
  ['Deniz', 'other', 26, 'Deniz kenarında gün batımı her şeye bedel.', ['Yüzme', 'Yoga', 'Resim']],
  ['Ayşe', 'female', 31, 'Kedimle birlikte paket servisiz. 🐱', ['Kediler', 'Dizi', 'Pilates']],
  ['Emre', 'male', 30, 'Koşu, podcast, bol çay.', ['Koşu', 'Podcast', 'Tarih']],
  ['Selin', 'female', 23, 'Üniversite son sınıf, mimarlık. Sergi arkadaşı arıyorum.', ['Sanat', 'Mimari', 'Dans']],
  ['Burak', 'male', 28, 'Bisikletle şehir turu atan biri.', ['Bisiklet', 'Kahve', 'Oyun']],
  ['İrem', 'female', 27, 'Sabah insanıyım, haberin olsun 🌅', ['Yoga', 'Kitap', 'Doğa']],
  ['Kaan', 'male', 33, 'Mutfakta iddialıyım, makarna konusunda tartışmaya açığım.', ['Yemek', 'Şarap', 'Seyahat']],
  ['Ece', 'female', 26, 'Konser listemde boş yer kalmadı.', ['Müzik', 'Festival', 'Fotoğraf']],
];

const COLORS = ['f87171', 'fb923c', 'facc15', '4ade80', '22d3ee', '818cf8', 'c084fc', 'f472b6'];

function argValue(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? Number(process.argv[i + 1]) : undefined;
}

// Merkezin etrafında rastgele bir nokta (en fazla ~maxKm uzaklıkta).
function nearby(lat, lng, maxKm) {
  const r = (Math.random() * maxKm) / 111;
  const t = Math.random() * 2 * Math.PI;
  return [lat + r * Math.cos(t), lng + (r * Math.sin(t)) / Math.cos((lat * Math.PI) / 180)];
}

function birthdateForAge(age) {
  const d = new Date();
  d.setUTCFullYear(d.getUTCFullYear() - age);
  d.setUTCDate(d.getUTCDate() - 1 - Math.floor(Math.random() * 300));
  return d.toISOString().slice(0, 10);
}

async function seed() {
  await migrate();

  let lat = argValue('lat');
  let lng = argValue('lng');
  const target = (await db.query(
    `SELECT id, name, lat, lng FROM users
     WHERE NOT is_demo AND lat IS NOT NULL ORDER BY last_active_at DESC LIMIT 1`
  )).rows[0];

  if (lat === undefined || lng === undefined) {
    if (!target) {
      console.log('Henüz konumu olan bir kullanıcı yok.');
      console.log('Önce uygulamadan kayıt olup konum izni verin, sonra "npm run seed" komutunu tekrar çalıştırın.');
      console.log('Ya da konumu elle verin:  npm run seed -- --lat 40.99 --lng 29.02');
      return;
    }
    lat = target.lat;
    lng = target.lng;
  }

  await db.query('DELETE FROM users WHERE is_demo');
  const hash = await bcrypt.hash(crypto.randomBytes(24).toString('hex'), 10);

  let i = 0;
  for (const [name, gender, age, bio, interests] of DEMO) {
    const [ulat, ulng] = nearby(lat, lng, 15);
    const email = `demo-${crypto.randomUUID()}@demo.pomp.local`;
    const { rows } = await db.query(
      `INSERT INTO users (email, password_hash, name, birthdate, gender, interested_in, bio, interests,
                          lat, lng, location_updated_at, is_demo, last_active_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10, now(), TRUE, now() - make_interval(mins => $11::int)) RETURNING id`,
      [email, hash, name, birthdateForAge(age), gender, ['male', 'female', 'other'], bio, interests, ulat, ulng, i * 7]
    );
    const id = rows[0].id;
    const color = COLORS[i % COLORS.length];
    for (let p = 0; p < 2; p++) {
      const url = `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&size=800&background=${p ? '1f2937' : color}&color=fff&font-size=0.33&format=png`;
      await db.query('INSERT INTO photos (user_id, url, position) VALUES ($1, $2, $3)', [id, url, p]);
    }
    if (target && i % 2 === 0) {
      await db.query('INSERT INTO swipes (swiper_id, target_id, liked) VALUES ($1, $2, TRUE)', [id, target.id]);
    }
    i++;
  }

  console.log(`${DEMO.length} demo kullanıcı oluşturuldu.`);
  if (target) console.log(`Bunların yarısı "${target.name}" kullanıcısını önceden beğendi; sağa kaydırınca eşleşeceksiniz.`);
}

seed()
  .catch((err) => {
    console.error('Demo kullanıcılar oluşturulamadı:', err.message);
    process.exitCode = 1;
  })
  .finally(() => db.pool.end());
