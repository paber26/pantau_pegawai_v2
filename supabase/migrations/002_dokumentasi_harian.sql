-- ============================================================
-- Tabel dokumentasi harian (tanpa relasi ke kegiatan/penugasan)
-- ============================================================
CREATE TABLE public.dokumentasi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
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

-- Pegawai bisa baca/tulis dokumentasi miliknya
CREATE POLICY "dokumentasi_self" ON public.dokumentasi
  FOR ALL USING (auth.uid() = user_id);

-- Admin bisa baca semua
CREATE POLICY "dokumentasi_admin_read" ON public.dokumentasi
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );

-- Admin bisa delete
CREATE POLICY "dokumentasi_admin_delete" ON public.dokumentasi
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
  );
