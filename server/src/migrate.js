const fs = require('fs');
const path = require('path');
const db = require('./db');

async function migrate() {
  const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
  await db.query(sql);
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
