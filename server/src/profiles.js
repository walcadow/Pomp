const db = require('./db');
const { ageFromBirthdate, photoUrl } = require('./util');

// Kullanıcıların fotoğraflarını tek sorguda getirir: { userId: [url, ...] }
async function photosFor(req, userIds) {
  if (userIds.length === 0) return {};
  const { rows } = await db.query(
    'SELECT id, user_id, url FROM photos WHERE user_id = ANY($1::uuid[]) ORDER BY position, created_at',
    [userIds]
  );
  const map = {};
  for (const r of rows) {
    (map[r.user_id] ||= []).push({ id: r.id, url: photoUrl(req, r.url) });
  }
  return map;
}

// Başkalarının göreceği profil (e-posta, tam doğum tarihi, konum gibi bilgiler gizli).
function publicProfile(row, photos) {
  return {
    id: row.id,
    name: row.name,
    age: ageFromBirthdate(row.birthdate),
    gender: row.gender,
    bio: row.bio,
    interests: row.interests,
    photos: photos || [],
    distanceKm: row.distance_km == null ? null : Math.max(1, Math.round(row.distance_km)),
  };
}

// Kullanıcının kendi profili.
function ownProfile(row, photos) {
  return {
    ...publicProfile(row, photos),
    email: row.email,
    birthdate: row.birthdate instanceof Date ? row.birthdate.toISOString().slice(0, 10) : row.birthdate,
    interestedIn: row.interested_in,
    minAge: row.min_age,
    maxAge: row.max_age,
    maxDistanceKm: row.max_distance_km,
    hasLocation: row.lat != null && row.lng != null,
    emailVerified: row.email_verified === true,
    distanceKm: null,
  };
}

async function loadOwnProfile(req, userId) {
  const { rows } = await db.query('SELECT * FROM users WHERE id = $1', [userId]);
  if (!rows[0]) return null;
  const photos = await photosFor(req, [userId]);
  return ownProfile(rows[0], photos[userId]);
}

module.exports = { photosFor, publicProfile, ownProfile, loadOwnProfile };
