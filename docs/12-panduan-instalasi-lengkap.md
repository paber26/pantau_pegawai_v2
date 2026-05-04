# Panduan Instalasi Lengkap — PantauPegawai

Dokumen ini adalah panduan end-to-end untuk menyiapkan seluruh infrastruktur dan menjalankan aplikasi **PantauPegawai** dari nol.

---

## Daftar Isi

1. [Prasyarat](#1-prasyarat)
2. [Setup Supabase](#2-setup-supabase)
3. [Setup Database (Migrasi SQL)](#3-setup-database-migrasi-sql)
4. [Konfigurasi Auth Supabase](#4-konfigurasi-auth-supabase)
5. [Setup Google Drive (OAuth2)](#5-setup-google-drive-oauth2)
6. [Deploy Edge Functions](#6-deploy-edge-functions)
7. [Konfigurasi Flutter App](#7-konfigurasi-flutter-app)
8. [Menjalankan Aplikasi](#8-menjalankan-aplikasi)
9. [Buat Akun Admin Pertama](#9-buat-akun-admin-pertama)
10. [Checklist Akhir](#10-checklist-akhir)

---

## 1. Prasyarat

Pastikan semua tools berikut sudah terinstall sebelum memulai.

### Tools Wajib

| Tool    | Versi Minimum | Link Install                                 |
| ------- | ------------- | -------------------------------------------- |
| Flutter | 3.41.0+       | https://flutter.dev/docs/get-started/install |
| Dart    | 3.11.0+       | Sudah termasuk dalam Flutter                 |
| Git     | Terbaru       | https://git-scm.com                          |
| Chrome  | Terbaru       | Untuk Flutter Web                            |

### Tools Opsional (untuk iOS/Android)

| Tool                 | Keterangan                       |
| -------------------- | -------------------------------- |
| Xcode 15+            | Wajib untuk build iOS (Mac only) |
| Android Studio 2023+ | Untuk build Android              |
| CocoaPods            | `sudo gem install cocoapods`     |

### Akun yang Dibutuhkan

- **Supabase** — https://supabase.com (gratis)
- **Google Cloud** — https://console.cloud.google.com (gratis, butuh kartu kredit untuk verifikasi)
- **Apple ID** — Untuk install di iPhone (gratis, atau $99/tahun untuk distribusi)

---

## 2. Setup Supabase

### 2.1 Buat Project Baru

1. Buka https://supabase.com → Login atau daftar
2. Klik **"New project"**
3. Isi form:
   - **Organization**: nama organisasi kamu
   - **Project name**: `pantau-pegawai`
   - **Database password**: buat password yang kuat, **simpan di tempat aman**
   - **Region**: `Southeast Asia (Singapore)` — paling dekat dengan Indonesia
4. Klik **"Create new project"**
5. Tunggu ~2 menit hingga project siap

### 2.2 Catat Project ID dan URL

Setelah project siap, catat informasi berikut dari dashboard:

- **Project URL**: `https://XXXXXXXXXXXX.supabase.co`
- **Project ID**: bagian `XXXXXXXXXXXX` dari URL di atas

### 2.3 Ambil API Keys

Buka: **Settings → API Keys**

> ⚠️ **Penting:** Gunakan **Legacy API Keys**, bukan Publishable Key.
> Format Publishable Key (`sb_publishable_...`) tidak kompatibel dengan `supabase_flutter ^2.x`.

Klik tab **"Legacy anon, service_role API keys"** dan catat:

| Key             | Keterangan               | Digunakan di                   |
| --------------- | ------------------------ | ------------------------------ |
| `anon` (public) | Key untuk client Flutter | `supabase_constants.dart`      |
| `service_role`  | Key admin (rahasia!)     | Supabase Edge Function secrets |

> 🔒 **JANGAN** taruh `service_role` key di kode Flutter. Hanya untuk Edge Functions.

---

## 3. Setup Database (Migrasi SQL)

### 3.1 Jalankan Migration Pertama

1. Buka Supabase Dashboard → **SQL Editor**
2. Klik **"New query"**
3. Copy-paste seluruh isi file `supabase/migrations/001_initial_schema.sql`
4. Klik **"Run"** (atau `Ctrl+Enter`)
5. Pastikan muncul pesan: `Success. No rows returned`

File ini membuat:

- Tabel `users`, `kegiatan`, `penugasan`, `laporan`
- Row Level Security (RLS) untuk semua tabel
- Helper function `is_admin()`
- Trigger `on_auth_user_created` (auto-create profil saat signup)
- Index untuk performa query

### 3.2 Jalankan Migration Kedua

1. Masih di SQL Editor → **"New query"**
2. Copy-paste seluruh isi file `supabase/migrations/002_dokumentasi_harian.sql`
3. Klik **"Run"**

File ini membuat:

- Tabel `dokumentasi` (fitur utama dokumentasi harian)
- RLS untuk tabel dokumentasi
- Index untuk performa

### 3.3 Verifikasi Tabel

Buka **Table Editor** di sidebar. Pastikan tabel berikut ada:

- ✅ `users`
- ✅ `kegiatan`
- ✅ `penugasan`
- ✅ `laporan`
- ✅ `dokumentasi`

---

## 4. Konfigurasi Auth Supabase

### 4.1 Nonaktifkan Email Confirmation

Karena ini aplikasi internal (admin yang buat akun pegawai), nonaktifkan konfirmasi email:

1. Buka **Authentication → Providers → Email**
2. Matikan toggle **"Confirm email"**
3. Klik **"Save"**

### 4.2 Konfigurasi URL (untuk Web)

1. Buka **Authentication → URL Configuration**
2. Isi **Site URL**: `http://localhost:PORT` (untuk development)
3. Tambahkan ke **Redirect URLs**: `http://localhost:PORT/**`

> Untuk production, ganti dengan URL hosting yang sebenarnya.

---

## 5. Setup Google Drive (OAuth2)

Aplikasi menggunakan Google Drive untuk menyimpan foto dokumentasi. Setup ini menggunakan **OAuth2 dengan Refresh Token** (bukan Service Account).

### 5.1 Buat Project di Google Cloud Console

1. Buka https://console.cloud.google.com
2. Klik dropdown project di atas → **"New Project"**
3. Isi **Project name**: `PantauPegawai`
4. Klik **"Create"**
5. Pastikan project baru sudah dipilih (cek dropdown di atas)

### 5.2 Aktifkan Google Drive API

1. Di sidebar kiri → **"APIs & Services" → "Library"**
2. Cari **"Google Drive API"**
3. Klik → **"Enable"**

### 5.3 Buat OAuth2 Credentials

1. Buka **"APIs & Services" → "Credentials"**
2. Klik **"+ Create Credentials" → "OAuth client ID"**
3. Jika diminta setup consent screen:
   - Klik **"Configure Consent Screen"**
   - Pilih **"External"** → **"Create"**
   - Isi **App name**: `PantauPegawai`
   - Isi **User support email**: email kamu
   - Isi **Developer contact email**: email kamu
   - Klik **"Save and Continue"** (lewati Scopes dan Test Users)
   - Klik **"Back to Dashboard"**
4. Kembali ke **Credentials → "+ Create Credentials" → "OAuth client ID"**
5. Pilih **Application type**: **"Web application"**
6. Isi **Name**: `PantauPegawai Web`
7. Di **Authorized redirect URIs**, tambahkan:
   ```
   https://developers.google.com/oauthplayground
   ```
8. Klik **"Create"**
9. **Catat** `Client ID` dan `Client Secret` yang muncul

### 5.4 Dapatkan Refresh Token via OAuth Playground

1. Buka https://developers.google.com/oauthplayground
2. Klik ikon ⚙️ (Settings) di pojok kanan atas
3. Centang **"Use your own OAuth credentials"**
4. Isi **OAuth Client ID** dan **OAuth Client Secret** dari langkah 5.3
5. Klik **"Close"**
6. Di panel kiri, cari dan pilih scope:
   - **Drive API v3** → centang `https://www.googleapis.com/auth/drive`
7. Klik **"Authorize APIs"**
8. Login dengan akun Google yang akan digunakan untuk menyimpan foto
9. Klik **"Allow"** untuk semua permission
10. Klik **"Exchange authorization code for tokens"**
11. **Catat** nilai `refresh_token` yang muncul

> ⚠️ Refresh token hanya muncul sekali. Simpan dengan aman!

### 5.5 Buat Folder Root di Google Drive

1. Buka https://drive.google.com dengan akun yang sama
2. Buat folder baru bernama `PantauPegawai` (atau nama lain sesuai kebutuhan)
3. Buka folder tersebut
4. **Catat Folder ID** dari URL browser:
   ```
   https://drive.google.com/drive/folders/FOLDER_ID_ADA_DI_SINI
   ```

---

## 6. Deploy Edge Functions

### 6.1 Tambahkan Secrets di Supabase

Buka: **Edge Functions → Secrets** (atau **Settings → Edge Functions**)

Tambahkan secrets berikut satu per satu:

| Secret Name                   | Value                                         | Keterangan       |
| ----------------------------- | --------------------------------------------- | ---------------- |
| `SERVICE_ROLE_KEY`            | `eyJhbGci...` (service role key)              | Dari langkah 2.3 |
| `GOOGLE_CLIENT_ID`            | `261324893158-xxx.apps.googleusercontent.com` | Dari langkah 5.3 |
| `GOOGLE_CLIENT_SECRET`        | `GOCSPX-xxx`                                  | Dari langkah 5.3 |
| `GOOGLE_REFRESH_TOKEN`        | `1//xxx...`                                   | Dari langkah 5.4 |
| `GOOGLE_DRIVE_ROOT_FOLDER_ID` | `1BxiMVs0XRA5...`                             | Dari langkah 5.5 |

> ⚠️ Nama secret **tidak boleh** diawali `SUPABASE_` — itu prefix reserved Supabase.

### 6.2 Deploy Functions via Browser (Cara Mudah)

Untuk setiap function di bawah, lakukan langkah berikut:

1. Buka **Edge Functions → "Deploy a new function" → "Via Editor"**
2. Isi nama function (sesuai tabel)
3. Copy-paste kode dari folder `supabase/functions/`
4. Klik **"Deploy"**

| Function Name          | File Kode                                          |
| ---------------------- | -------------------------------------------------- |
| `admin-create-user`    | `supabase/functions/admin-create-user/index.ts`    |
| `admin-delete-user`    | `supabase/functions/admin-delete-user/index.ts`    |
| `admin-reset-password` | `supabase/functions/admin-reset-password/index.ts` |
| `upload-to-drive`      | `supabase/functions/upload-to-drive/index.ts`      |
| `image-proxy`          | `supabase/functions/image-proxy/index.ts`          |

### 6.3 Deploy Functions via CLI (Cara Alternatif)

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Login (dapatkan token dari https://supabase.com/dashboard/account/tokens)
supabase login --token sbp_YOUR_PERSONAL_ACCESS_TOKEN

# Deploy semua functions (ganti YOUR_PROJECT_ID dengan project ID kamu)
supabase functions deploy admin-create-user --project-ref YOUR_PROJECT_ID
supabase functions deploy admin-delete-user --project-ref YOUR_PROJECT_ID
supabase functions deploy admin-reset-password --project-ref YOUR_PROJECT_ID
supabase functions deploy upload-to-drive --project-ref YOUR_PROJECT_ID
supabase functions deploy image-proxy --project-ref YOUR_PROJECT_ID
```

### 6.4 Verifikasi Functions

Setelah deploy, semua function harus muncul di **Edge Functions** dengan status **Active**.

---

## 7. Konfigurasi Flutter App

### 7.1 Clone / Buka Project

```bash
git clone <repository-url>
cd pantau_pegawai
```

### 7.2 Buat File Credentials

Buat file `lib/core/constants/supabase_constants.dart`:

> ⚠️ File ini ada di `.gitignore` dan **tidak boleh di-commit** ke repository.

```dart
class SupabaseConstants {
  SupabaseConstants._();

  // Dari Supabase Dashboard → Settings → API
  static const String url = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String anonKey = 'eyJhbGci...'; // Legacy anon key

  // URL Edge Functions (otomatis menggunakan url di atas)
  static const String uploadDriveFunctionUrl =
      '$url/functions/v1/upload-to-drive';

  static const String imageProxyUrl = '$url/functions/v1/image-proxy';
}
```

Ganti:

- `YOUR_PROJECT_ID` → Project ID dari Supabase (contoh: `glywzqbifjordhwulpbw`)
- `eyJhbGci...` → Legacy anon key dari Supabase

### 7.3 Install Dependencies

```bash
flutter pub get
```

### 7.4 Generate Riverpod Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Perintah ini men-generate file `*.g.dart` untuk semua provider dengan `@riverpod` annotation.

### 7.5 Setup iOS (Mac only)

```bash
cd ios
pod install
cd ..
```

---

## 8. Menjalankan Aplikasi

### Flutter Web (Admin Dashboard)

```bash
# Development — CORS disabled diperlukan untuk localhost
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

> Di production (hosting), flag ini tidak diperlukan.

### Flutter iOS

```bash
# Lihat device yang terhubung
flutter devices

# Jalankan ke iPhone (ganti DEVICE_ID)
flutter run -d DEVICE_ID

# Atau mode release
flutter run --release -d DEVICE_ID
```

Setelah install pertama kali di iPhone:

1. **Settings → General → VPN & Device Management**
2. Tap nama Apple ID → **"Trust"**

### Flutter Android

```bash
# Jalankan ke device Android
flutter run -d DEVICE_ID

# Build APK release
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## 9. Buat Akun Admin Pertama

### 9.1 Buat User via Supabase Dashboard

1. Buka **Authentication → Users → "Add user" → "Create new user"**
2. Isi:
   - **Email**: `admin@instansi.go.id`
   - **Password**: password yang kuat
3. Klik **"Create user"**

### 9.2 Set Role Admin via SQL

1. Buka **SQL Editor → New query**
2. Jalankan:

```sql
UPDATE public.users
SET
  role = 'admin',
  nama = 'Administrator',
  jabatan = 'Admin Sistem',
  unit_kerja = 'IT'
WHERE email = 'admin@instansi.go.id';
```

3. Verifikasi:

```sql
SELECT id, nama, email, role FROM public.users WHERE role = 'admin';
```

### 9.3 Login ke Aplikasi

- Buka Flutter Web (Admin Dashboard)
- Login dengan email dan password admin yang baru dibuat
- Setelah login, akan diarahkan ke halaman Dashboard Admin

---

## 10. Checklist Akhir

Gunakan checklist ini untuk memastikan semua sudah dikonfigurasi dengan benar.

### Supabase

- [ ] Project Supabase sudah dibuat
- [ ] Migration `001_initial_schema.sql` sudah dijalankan
- [ ] Migration `002_dokumentasi_harian.sql` sudah dijalankan
- [ ] Email confirmation sudah dinonaktifkan
- [ ] Semua 5 Edge Functions sudah di-deploy dan Active
- [ ] Semua secrets sudah ditambahkan di Edge Functions

### Google Drive

- [ ] Google Cloud project sudah dibuat
- [ ] Google Drive API sudah diaktifkan
- [ ] OAuth2 credentials sudah dibuat
- [ ] Refresh token sudah didapatkan via OAuth Playground
- [ ] Folder root di Google Drive sudah dibuat dan ID-nya dicatat

### Flutter App

- [ ] File `supabase_constants.dart` sudah dibuat dengan credentials yang benar
- [ ] `flutter pub get` sudah dijalankan
- [ ] `build_runner build` sudah dijalankan
- [ ] Aplikasi bisa login dengan akun admin

### Verifikasi Fungsional

- [ ] Login admin berhasil → masuk ke Dashboard
- [ ] Login pegawai berhasil → masuk ke halaman Kegiatan
- [ ] Admin bisa tambah pegawai baru
- [ ] Pegawai bisa upload foto dokumentasi → foto tersimpan di Google Drive
- [ ] Foto bisa ditampilkan di aplikasi via image-proxy

---

## Troubleshooting Umum

### Error: "Invalid API key"

**Penyebab:** Menggunakan Publishable Key bukan Legacy Anon Key.
**Solusi:** Ganti dengan Legacy anon key dari tab "Legacy anon, service_role API keys".

### Error: "Edge Function returned non-2xx status"

**Penyebab:** Secrets belum dikonfigurasi atau salah.
**Solusi:** Cek **Edge Functions → Secrets**, pastikan semua secret sudah ada dan nilainya benar.

### Error: "Gagal refresh access token"

**Penyebab:** `GOOGLE_REFRESH_TOKEN` expired atau salah.
**Solusi:** Ulangi langkah 5.4 untuk mendapatkan refresh token baru.

### Error: "LocaleDataException: Locale data has not been initialized"

**Penyebab:** `initializeDateFormatting` belum dipanggil.
**Solusi:** Pastikan `main.dart` memanggil `await initializeDateFormatting('id_ID', null)` sebelum `runApp()`.

### Error: "No signing certificate" (iOS)

**Solusi:** Buka Xcode → **Settings → Accounts** → tambahkan Apple ID.

### Build Android gagal: "JDK 17 or higher is required"

```bash
brew install --cask temurin@17
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
source ~/.zshrc
```

### RLS Error: "new row violates row-level security policy"

**Penyebab:** Policy RLS tidak mengizinkan operasi tersebut.
**Solusi:** Cek policy di **Table Editor → [nama tabel] → Policies**. Pastikan trigger `handle_new_user` berjalan dengan benar saat user baru dibuat.
