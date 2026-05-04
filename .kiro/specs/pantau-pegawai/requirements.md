# Requirements: PantauPegawai

## Overview

PantauPegawai adalah aplikasi monitoring pegawai berbasis Flutter yang terdiri dari dua platform:

- **Flutter Android** — untuk pegawai (field worker)
- **Flutter Web/Desktop** — untuk admin dashboard

Backend menggunakan Supabase (Auth, PostgreSQL, Realtime, RLS) dan Google Drive untuk penyimpanan foto laporan.

---

## Functional Requirements

### FR-01: Authentication

- **FR-01.1** Pegawai dan admin dapat login menggunakan email dan password via Supabase Auth.
- **FR-01.2** Session disimpan secara persisten di device.
- **FR-01.3** Logout menghapus session lokal.
- **FR-01.4** Role-based redirect: admin diarahkan ke dashboard, pegawai ke halaman kegiatan.

### FR-02: Manajemen Pegawai (Admin)

- **FR-02.1** Admin dapat melihat daftar seluruh pegawai.
- **FR-02.2** Admin dapat menambah pegawai baru (nama, email, jabatan, unit_kerja, role).
- **FR-02.3** Admin dapat mengedit data pegawai.
- **FR-02.4** Admin dapat menghapus pegawai.
- **FR-02.5** Saat pegawai baru dibuat, akun Supabase Auth juga dibuat via Admin API.

### FR-03: Manajemen Kegiatan (Admin)

- **FR-03.1** Admin dapat membuat kegiatan baru (judul, deskripsi, deadline).
- **FR-03.2** Admin dapat mengedit kegiatan.
- **FR-03.3** Admin dapat menghapus kegiatan.
- **FR-03.4** Admin dapat melihat daftar semua kegiatan.

### FR-04: Penugasan Kegiatan (Admin)

- **FR-04.1** Admin dapat assign satu kegiatan ke satu atau banyak pegawai.
- **FR-04.2** Admin dapat melihat siapa saja yang sudah di-assign ke suatu kegiatan.
- **FR-04.3** Admin dapat mencabut penugasan.

### FR-05: Upload Laporan (Pegawai)

- **FR-05.1** Pegawai dapat mengambil foto dari kamera.
- **FR-05.2** Pegawai dapat memilih foto dari galeri.
- **FR-05.3** Pegawai mengisi deskripsi laporan.
- **FR-05.4** Timestamp dibuat otomatis saat submit.
- **FR-05.5** Foto diupload ke Google Drive via Supabase Edge Function dengan struktur folder: `/PantauPegawai/{nama_pegawai}/{yyyy-mm-dd}/foto_{timestamp}.jpg`
- **FR-05.6** Metadata laporan (user_id, kegiatan_id, image_url, deskripsi, created_at) disimpan ke tabel `laporan` di Supabase.

### FR-06: Melihat Kegiatan (Pegawai)

- **FR-06.1** Pegawai melihat daftar kegiatan yang di-assign kepadanya.
- **FR-06.2** Pegawai dapat melihat detail kegiatan (judul, deskripsi, deadline).
- **FR-06.3** Pegawai dapat melihat status apakah sudah upload laporan untuk kegiatan tersebut.

### FR-07: Riwayat Laporan (Pegawai)

- **FR-07.1** Pegawai dapat melihat daftar laporan yang pernah diupload.
- **FR-07.2** Pegawai dapat melihat detail laporan (foto, deskripsi, timestamp).

### FR-08: Dashboard Admin

- **FR-08.1** Menampilkan statistik: jumlah pegawai, kegiatan aktif, laporan masuk, pegawai belum upload.
- **FR-08.2** Melihat semua laporan masuk dengan filter tanggal, pegawai, dan kegiatan.
- **FR-08.3** Melihat detail laporan termasuk foto dari Google Drive.
- **FR-08.4** Realtime update saat pegawai baru upload laporan.

---

## Non-Functional Requirements

### NFR-01: Security

- Row Level Security (RLS) aktif di semua tabel Supabase.
- Pegawai hanya bisa membaca/menulis data miliknya sendiri.
- Google Drive credentials tidak pernah dikirim ke client — hanya diakses via Edge Function.
- Service role key Supabase hanya digunakan di Edge Function.

### NFR-02: Performance

- Daftar laporan menggunakan pagination (20 item per halaman).
- Gambar ditampilkan dengan lazy loading.

### NFR-03: Usability

- UI mobile-first untuk Flutter Android.
- UI responsive untuk Flutter Web/Desktop (sidebar navigation).
- Bahasa Indonesia untuk semua label UI.

### NFR-04: Scalability

- Arsitektur feature-based agar mudah menambah fitur baru.
- State management dengan Riverpod.

---

## Database Schema

```sql
-- Table: users (extends auth.users)
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nama TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  jabatan TEXT,
  unit_kerja TEXT,
  role TEXT NOT NULL DEFAULT 'pegawai', -- 'admin' | 'pegawai'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table: kegiatan
CREATE TABLE public.kegiatan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  judul TEXT NOT NULL,
  deskripsi TEXT,
  deadline DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Table: penugasan
CREATE TABLE public.penugasan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  kegiatan_id UUID NOT NULL REFERENCES public.kegiatan(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, kegiatan_id)
);

-- Table: laporan
CREATE TABLE public.laporan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  kegiatan_id UUID NOT NULL REFERENCES public.kegiatan(id) ON DELETE CASCADE,
  image_url TEXT NOT NULL,
  deskripsi TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Row Level Security Policies

```sql
-- users: pegawai hanya bisa baca/update data sendiri, admin bisa semua
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_self" ON public.users FOR ALL USING (auth.uid() = id);
CREATE POLICY "users_admin" ON public.users FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- kegiatan: semua authenticated user bisa baca, hanya admin yang bisa write
ALTER TABLE public.kegiatan ENABLE ROW LEVEL SECURITY;
CREATE POLICY "kegiatan_read" ON public.kegiatan FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "kegiatan_admin" ON public.kegiatan FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- penugasan: pegawai baca penugasan miliknya, admin bisa semua
ALTER TABLE public.penugasan ENABLE ROW LEVEL SECURITY;
CREATE POLICY "penugasan_self" ON public.penugasan FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "penugasan_admin" ON public.penugasan FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);

-- laporan: pegawai baca/tulis laporan miliknya, admin bisa semua
ALTER TABLE public.laporan ENABLE ROW LEVEL SECURITY;
CREATE POLICY "laporan_self" ON public.laporan FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "laporan_admin" ON public.laporan FOR ALL USING (
  EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);
```
