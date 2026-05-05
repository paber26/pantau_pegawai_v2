-- ============================================================
-- PantauPegawai - Initial Schema
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLE: users
-- Extends auth.users dengan data profil pegawai
-- ============================================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nama TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  jabatan TEXT,
  unit_kerja TEXT,
  role TEXT NOT NULL DEFAULT 'pegawai' CHECK (role IN ('admin', 'pegawai')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: kegiatan
-- ============================================================
CREATE TABLE public.kegiatan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  judul TEXT NOT NULL,
  deskripsi TEXT,
  deadline DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLE: penugasan
-- Relasi many-to-many antara users dan kegiatan
-- ============================================================
CREATE TABLE public.penugasan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  kegiatan_id UUID NOT NULL REFERENCES public.kegiatan(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, kegiatan_id)
);

-- ============================================================
-- TABLE: laporan
-- ============================================================
CREATE TABLE public.laporan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  kegiatan_id UUID NOT NULL REFERENCES public.kegiatan(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  deskripsi TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- Helper function: cek apakah user adalah admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- ── users ──────────────────────────────────────────────────
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Semua authenticated user bisa baca semua profil (diperlukan untuk join dokumentasi)
CREATE POLICY "users_all_read" ON public.users
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "users_self_update" ON public.users
  FOR UPDATE USING (auth.uid() = id OR public.is_admin());

-- Admin bisa insert dan delete
CREATE POLICY "users_admin_insert" ON public.users
  FOR INSERT WITH CHECK (public.is_admin());

CREATE POLICY "users_admin_delete" ON public.users
  FOR DELETE USING (public.is_admin());

-- ── kegiatan ───────────────────────────────────────────────
ALTER TABLE public.kegiatan ENABLE ROW LEVEL SECURITY;

-- Semua authenticated user bisa baca
CREATE POLICY "kegiatan_select" ON public.kegiatan
  FOR SELECT USING (auth.role() = 'authenticated');

-- Hanya admin yang bisa write
CREATE POLICY "kegiatan_admin_write" ON public.kegiatan
  FOR ALL USING (public.is_admin());

-- ── penugasan ──────────────────────────────────────────────
ALTER TABLE public.penugasan ENABLE ROW LEVEL SECURITY;

-- Pegawai bisa baca penugasan miliknya
CREATE POLICY "penugasan_self_select" ON public.penugasan
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

-- Hanya admin yang bisa write
CREATE POLICY "penugasan_admin_write" ON public.penugasan
  FOR ALL USING (public.is_admin());

-- ── laporan ────────────────────────────────────────────────
ALTER TABLE public.laporan ENABLE ROW LEVEL SECURITY;

-- Pegawai bisa baca laporan miliknya, admin bisa semua
CREATE POLICY "laporan_select" ON public.laporan
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

-- Pegawai bisa insert laporan miliknya
CREATE POLICY "laporan_insert" ON public.laporan
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Admin bisa update/delete
CREATE POLICY "laporan_admin_write" ON public.laporan
  FOR ALL USING (public.is_admin());

-- ============================================================
-- TRIGGER: Auto-create user profile saat signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, nama, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'nama', split_part(NEW.email, '@', 1)),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'pegawai')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- INDEXES untuk performa
-- ============================================================
CREATE INDEX idx_penugasan_user_id ON public.penugasan(user_id);
CREATE INDEX idx_penugasan_kegiatan_id ON public.penugasan(kegiatan_id);
CREATE INDEX idx_laporan_user_id ON public.laporan(user_id);
CREATE INDEX idx_laporan_kegiatan_id ON public.laporan(kegiatan_id);
CREATE INDEX idx_laporan_created_at ON public.laporan(created_at DESC);

-- ============================================================
-- SEED: Admin default (ganti password setelah deploy!)
-- ============================================================
-- Jalankan ini secara manual di Supabase Dashboard > SQL Editor
-- setelah membuat user admin via Authentication > Users:
--
-- UPDATE public.users
-- SET role = 'admin', nama = 'Administrator', jabatan = 'Admin Sistem'
-- WHERE email = 'admin@instansi.go.id';
