-- E-posta doğrulama ve şifre sıfırlama (6 haneli kodlar).
-- Bu dosya her açılışta çalışır; tekrar tekrar çalıştırılması güvenlidir.

ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE;

-- Demo hesapların e-postası gerçek değil; doğrulanmış sayılır.
UPDATE users SET email_verified = TRUE WHERE is_demo AND NOT email_verified;

CREATE TABLE IF NOT EXISTS email_codes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose     TEXT NOT NULL CHECK (purpose IN ('verify', 'reset')),
  code_hash   TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  attempts    INT NOT NULL DEFAULT 0,
  used_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS email_codes_user_purpose_idx ON email_codes (user_id, purpose, created_at DESC);
