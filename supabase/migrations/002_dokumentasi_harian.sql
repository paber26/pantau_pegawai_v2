-- ============================================================
-- Tabel dokumentasi harian (tanpa relasi ke kegiatan/penugasan)
-- ============================================================
CREATE TABLE public.dokumentasi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  pegawai_nama TEXT,              -- nama pegawai (disimpan langsung, tidak bergantung join)
  proyek TEXT NOT NULL,           -- nama proyek/kegiatan bebas input
  tanggal_kegiatan DATE NOT NULL DEFAULT CURRENT_DATE,
  image_url TEXT,                 -- URL foto di Google Drive (opsional)
  catatan TEXT,                   -- deskripsi/catatan kegiatan
  link TEXT,                      -- link referensi (opsional)
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX idx_dokumentasi_user_id ON public.dokumentasi(user_id);
CREATE INDEX idx_dokumentasi_tanggal ON public.dokumentasi(tanggal_kegiatan DESC);
CREATE INDEX idx_dokumentasi_created_at ON public.dokumentasi(created_at DESC);

-- RLS
ALTER TABLE public.dokumentasi ENABLE ROW LEVEL SECURITY;

-- Semua authenticated user bisa baca semua dokumentasi
CREATE POLICY "dokumentasi_all_read" ON public.dokumentasi
  FOR SELECT USING (auth.role() = 'authenticated');

-- Pegawai hanya bisa insert dokumentasi miliknya
CREATE POLICY "dokumentasi_self_write" ON public.dokumentasi
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Pegawai hanya bisa update dokumentasi miliknya
CREATE POLICY "dokumentasi_self_update" ON public.dokumentasi
  FOR UPDATE USING (auth.uid() = user_id);

-- Pegawai bisa delete miliknya, admin bisa delete semua
CREATE POLICY "dokumentasi_self_delete" ON public.dokumentasi
  FOR DELETE USING (auth.uid() = user_id OR public.is_admin());
