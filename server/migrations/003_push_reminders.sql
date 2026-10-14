-- ============================================================
-- Pengingat harian lewat notifikasi web (Web Push).
-- ============================================================

-- Satu baris per browser/perangkat yang mengaktifkan pengingat. Terikat ke
-- sesi login: logout, ganti/reset password, atau hapus pegawai otomatis
-- menghapus langganannya, jadi perangkat itu berhenti menerima pengingat.
CREATE TABLE push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  endpoint TEXT NOT NULL UNIQUE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_push_subscriptions_user_id ON push_subscriptions(user_id);
CREATE INDEX idx_push_subscriptions_session_id ON push_subscriptions(session_id);

-- Satu baris per hari pengingat dikirim, agar tidak terkirim dua kali
-- (mis. API di-restart setelah jam pengingat).
CREATE TABLE reminder_runs (
  tanggal DATE PRIMARY KEY,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sent INT NOT NULL DEFAULT 0,
  failed INT NOT NULL DEFAULT 0
);
