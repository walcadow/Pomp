-- Anlık bildirimler (Firebase Cloud Messaging) için cihaz anahtarları.
-- Bir cihaz anahtarı (token) aynı anda yalnızca bir kullanıcıya ait olabilir.
CREATE TABLE IF NOT EXISTS push_tokens (
  token       TEXT PRIMARY KEY,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform    TEXT NOT NULL DEFAULT 'android',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS push_tokens_user_idx ON push_tokens(user_id);
