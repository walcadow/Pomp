-- Yönetici paneli (/admin) için ek alanlar.
-- Bu dosya her açılışta çalışır; tekrar tekrar çalıştırılması güvenlidir.

ALTER TABLE users ADD COLUMN IF NOT EXISTS banned_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS ban_reason TEXT;

ALTER TABLE reports ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS admin_action TEXT;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS admin_note TEXT;

CREATE INDEX IF NOT EXISTS reports_reported_idx ON reports (reported_id);
CREATE INDEX IF NOT EXISTS reports_status_idx ON reports (status, created_at DESC);
