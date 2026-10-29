const http = require('http');
const path = require('path');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const config = require('./config');
const migrate = require('./migrate');
const realtime = require('./realtime');

const app = express();
app.set('trust proxy', 1);
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(cors());
app.use(express.json({ limit: '100kb' }));

// Yüklenen fotoğraflar ve yasal metinler
app.use('/uploads', express.static(config.uploadDir, { maxAge: '7d', fallthrough: false }));
app.use('/legal', express.static(path.join(__dirname, '..', 'public', 'legal'), { extensions: ['html'] }));

app.get('/health', (req, res) => res.json({ ok: true }));

app.use('/auth', require('./routes/auth'));
app.use('/me', require('./routes/me'));
app.use('/', require('./routes/discover'));
app.use('/matches', require('./routes/matches'));
app.use('/users', require('./routes/users'));

app.use((req, res) => res.status(404).json({ error: 'Bulunamadı.' }));

// Hata yakalayıcı: beklenen hatalarda mesajı, beklenmeyenlerde genel bir mesaj döndürür.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err.code === 'LIMIT_FILE_SIZE') return res.status(400).json({ error: 'Fotoğraf en fazla 8 MB olabilir.' });
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'Geçersiz istek.' });
  if (err.status && err.status < 500) return res.status(err.status).json({ error: err.message });
  console.error(err);
  res.status(500).json({ error: 'Sunucuda bir hata oluştu. Lütfen tekrar deneyin.' });
});

async function start() {
  await migrate();
  const server = http.createServer(app);
  realtime.init(server);
  await new Promise((resolve) => server.listen(config.port, '0.0.0.0', resolve));
  console.log(`Pomp sunucusu çalışıyor: http://localhost:${config.port}`);
  return server;
}

if (require.main === module) {
  start().catch((err) => {
    console.error('Sunucu başlatılamadı:', err.message);
    if (/ECONNREFUSED/.test(err.message)) {
      console.error('Veritabanına ulaşılamadı. "docker compose up -d db" komutunu çalıştırdınız mı?');
    }
    process.exit(1);
  });
}

module.exports = { app, start };
