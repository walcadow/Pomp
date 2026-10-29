const fs = require('fs');
const path = require('path');
const db = require('./db');

// Önce ana şema, ardından migrations/ klasöründeki ek dosyalar (sırayla) çalışır.
// Tüm dosyalar tekrar tekrar çalıştırılmaya uygundur (IF NOT EXISTS), bu yüzden her açılışta uygulanır.
async function migrate() {
  await db.query(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8'));
  const dir = path.join(__dirname, 'migrations');
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort() : [];
  for (const f of files) {
    await db.query(fs.readFileSync(path.join(dir, f), 'utf8'));
  }
}

module.exports = migrate;

if (require.main === module) {
  migrate()
    .then(() => {
      console.log('Veritabanı tabloları hazır.');
      return db.pool.end();
    })
    .catch((err) => {
      console.error('Tablolar oluşturulamadı:', err.message);
      process.exit(1);
    });
}
