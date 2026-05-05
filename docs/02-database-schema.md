# Tahap 2 — Database Schema Supabase

## 2.1 Tabel-Tabel

### `users` — Profil pegawai (extends auth.users)

```sql
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nama TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  jabatan TEXT,
  unit_kerja TEXT,
  role TEXT NOT NULL DEFAULT 'pegawai' CHECK (role IN ('admin', 'pegawai')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### `kegiatan` — Daftar kegiatan/tugas

```sql
CREATE TABLE public.kegiatan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  judul TEXT NOT NULL,
  deskripsi TEXT,
  deadline DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### `penugasan` — Relasi pegawai ↔ kegiatan

```sql
CREATE TABLE public.penugasan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  kegiatan_id UUID NOT NULL REFERENCES public.kegiatan(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, kegiatan_id)
);
```

### `laporan` — Laporan kegiatan (dengan penugasan)

```sql
CREATE TABLE public.laporan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  kegiatan_id UUID NOT NULL REFERENCES public.kegiatan(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  deskripsi TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### `dokumentasi` — Dokumentasi harian (tanpa penugasan) ⭐ Fitur Utama

```sql
CREATE TABLE public.dokumentasi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  pegawai_nama TEXT,       -- nama pegawai (disimpan langsung, tidak bergantung join)
  proyek TEXT NOT NULL,
  tanggal_kegiatan DATE NOT NULL DEFAULT CURRENT_DATE,
  image_url TEXT,          -- URL image-proxy Supabase: .../image-proxy?id={FILE_ID}
  catatan TEXT,
  link TEXT,               -- opsional
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

> **Catatan:** Kolom `pegawai_nama` ditambahkan agar nama pegawai bisa ditampilkan tanpa bergantung pada JOIN ke tabel `users` (yang dibatasi RLS). Diisi otomatis saat insert dari Flutter.

## 2.2 Row Level Security (RLS)

### Helper function

```sql
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER;
```

### Policy ringkasan

| Tabel       | Pegawai                           | Admin               |
| ----------- | --------------------------------- | ------------------- |
| users       | Baca semua profil, update sendiri | Semua operasi       |
| kegiatan    | Baca semua                        | Semua operasi       |
| penugasan   | Baca milik sendiri                | Semua operasi       |
| laporan     | Baca/tulis milik sendiri          | Semua operasi       |
| dokumentasi | Baca semua, tulis milik sendiri   | Baca + delete semua |

> **Catatan perubahan RLS:**
>
> - `users`: policy diubah dari "baca data sendiri" menjadi "semua authenticated user bisa baca semua profil" — diperlukan agar nama pegawai bisa ditampilkan di halaman Dokumentasi.
> - `dokumentasi`: policy diubah dari "semua operasi milik sendiri" menjadi "baca semua + tulis milik sendiri" — agar semua pegawai bisa melihat dokumentasi rekan kerja.

## 2.3 Trigger Auto-Create User Profile

Saat user baru dibuat di `auth.users`, trigger ini otomatis insert ke `public.users`:

```sql
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
```

> **Catatan penting:** Karena trigger ini berjalan otomatis, Edge Function `admin-create-user` menggunakan `UPDATE` (bukan `INSERT`) untuk mengisi data profil lengkap setelah auth user dibuat.

## 2.4 Cara Menjalankan Migration

1. Buka Supabase Dashboard → **SQL Editor**
2. Klik **New query**
3. Copy-paste isi file `supabase/migrations/001_initial_schema.sql`
4. Klik **Run**
5. Ulangi untuk `supabase/migrations/002_dokumentasi_harian.sql`
6. Jalankan SQL tambahan berikut untuk update RLS dan tambah kolom `pegawai_nama`:

```sql
-- Tambah kolom pegawai_nama di tabel dokumentasi
ALTER TABLE public.dokumentasi
ADD COLUMN IF NOT EXISTS pegawai_nama TEXT;

-- Isi pegawai_nama dari data users yang sudah ada
UPDATE public.dokumentasi d
SET pegawai_nama = u.nama
FROM public.users u
WHERE d.user_id = u.id AND d.pegawai_nama IS NULL;

-- Update RLS dokumentasi: semua authenticated user bisa baca
DROP POLICY IF EXISTS "dokumentasi_self" ON public.dokumentasi;
CREATE POLICY "dokumentasi_all_read" ON public.dokumentasi
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "dokumentasi_self_write" ON public.dokumentasi
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "dokumentasi_self_update" ON public.dokumentasi
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "dokumentasi_self_delete" ON public.dokumentasi
  FOR DELETE USING (auth.uid() = user_id OR public.is_admin());

-- Update RLS users: semua authenticated user bisa baca semua profil
DROP POLICY IF EXISTS "users_self_select" ON public.users;
CREATE POLICY "users_all_read" ON public.users
  FOR SELECT USING (auth.role() = 'authenticated');
```

## 2.5 Setup Admin Pertama

Setelah migration, buat user admin:

1. Supabase Dashboard → **Authentication → Users → Add user**
2. Isi email dan password
3. Jalankan SQL:

```sql
UPDATE public.users
SET role = 'admin', nama = 'Nama Admin', jabatan = 'Admin Sistem'
WHERE email = 'admin@instansi.go.id';
```
