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
  proyek TEXT NOT NULL,
  tanggal_kegiatan DATE NOT NULL DEFAULT CURRENT_DATE,
  image_url TEXT,          -- opsional
  catatan TEXT,
  link TEXT,               -- opsional
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

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

| Tabel       | Pegawai                     | Admin               |
| ----------- | --------------------------- | ------------------- |
| users       | Baca/update data sendiri    | Semua operasi       |
| kegiatan    | Baca semua                  | Semua operasi       |
| penugasan   | Baca milik sendiri          | Semua operasi       |
| laporan     | Baca/tulis milik sendiri    | Semua operasi       |
| dokumentasi | Semua operasi milik sendiri | Baca + delete semua |

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
