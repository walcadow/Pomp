require('dotenv').config();

const config = {
  port: Number(process.env.PORT || 3000),
  databaseUrl: process.env.DATABASE_URL || 'postgres://pomp:pomp@localhost:5432/pomp',
  jwtSecret: process.env.JWT_SECRET || '',
  // Sunucunun dışarıdan erişilen adresi; yüklenen fotoğrafların linkleri bununla oluşturulur.
  publicUrl: (process.env.PUBLIC_URL || '').replace(/\/$/, ''),
  uploadDir: process.env.UPLOAD_DIR || require('path').join(__dirname, '..', 'uploads'),
  maxPhotos: 6,
  // Geliştirme ortamında fotoğrafı olmayan profiller de keşfette görünür.
  allowNoPhoto: process.env.NODE_ENV !== 'production',
  minAge: 18,
};

if (!config.jwtSecret || config.jwtSecret.length < 32) {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('JWT_SECRET en az 32 karakter olmalı. .env dosyasını kontrol edin.');
  }
  // Geliştirme ortamında uyarı verip devam ediyoruz.
  config.jwtSecret = config.jwtSecret || 'gelistirme-icin-gizli-anahtar-uretimde-degistirin';
  console.warn('UYARI: JWT_SECRET ayarlanmamış ya da çok kısa. Yayına almadan önce .env dosyasında değiştirin.');
}

module.exports = config;
