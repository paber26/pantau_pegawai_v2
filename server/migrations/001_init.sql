-- ============================================================
-- PantauPegawai - Skema awal (PostgreSQL di VPS)
--
-- Struktur tabel sama dengan skema Supabase lama
-- (supabase/migrations/001_initial_schema.sql + 002_dokumentasi_harian.sql),
-- dengan perbedaan:
--   - users menyimpan password_hash sendiri (tidak ada lagi auth.users)
--   - tabel sessions untuk token login
--   - tanpa RLS/trigger: aturan akses ditegakkan oleh API (server/src/routes)
-- ============================================================

-- ============================================================
-- TABLE: users
-- ============================================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama TEXT NOT NULL,
  email TEXT NOT NULL,
  jabatan TEXT,
  unit_kerja TEXT,
  role TEXT NOT NULL DEFAULT 'pegawai' CHECK (role IN ('admin', 'pegawai')),
  -- Hash bcrypt. NULL = belum punya password (harus di-reset admin dulu).
  password_hash TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX users_email_lower_key ON users (lower(email));

-- ============================================================
-- TABLE: sessions
-- Token login (opaque). Yang disimpan hanya hash SHA-256 dari token.
-- ============================================================
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  last_used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);

-- ============================================================
-- TABLE: kegiatan
-- ============================================================
CREATE TABLE kegiatan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  judul TEXT NOT NULL,
  deskripsi TEXT,
  deadline DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: penugasan
-- Relasi many-to-many antara users dan kegiatan
-- ============================================================
CREATE TABLE penugasan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kegiatan_id UUID NOT NULL REFERENCES kegiatan(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, kegiatan_id)
);

-- ============================================================
-- TABLE: laporan
-- ============================================================
CREATE TABLE laporan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kegiatan_id UUID NOT NULL REFERENCES kegiatan(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  deskripsi TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLE: dokumentasi
-- Dokumentasi harian (tanpa relasi ke kegiatan/penugasan)
-- ============================================================
CREATE TABLE dokumentasi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pegawai_nama TEXT,              -- nama pegawai (disimpan langsung, tidak bergantung join)
  proyek TEXT NOT NULL,           -- nama proyek/kegiatan bebas input
  tanggal_kegiatan DATE NOT NULL,
  image_url TEXT,                 -- URL foto (image proxy API, atau URL Google Drive lama)
  catatan TEXT,
  link TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_penugasan_user_id ON penugasan(user_id);
CREATE INDEX idx_penugasan_kegiatan_id ON penugasan(kegiatan_id);
CREATE INDEX idx_laporan_user_id ON laporan(user_id);
CREATE INDEX idx_laporan_kegiatan_id ON laporan(kegiatan_id);
CREATE INDEX idx_laporan_created_at ON laporan(created_at DESC);
CREATE INDEX idx_dokumentasi_user_id ON dokumentasi(user_id);
CREATE INDEX idx_dokumentasi_tanggal ON dokumentasi(tanggal_kegiatan DESC);
CREATE INDEX idx_dokumentasi_created_at ON dokumentasi(created_at DESC);
