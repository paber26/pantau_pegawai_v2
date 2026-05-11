# Tahap 10 — Cara Menjalankan Aplikasi

## Prasyarat

| Tool           | Versi   | Cara Install                                 |
| -------------- | ------- | -------------------------------------------- |
| Flutter        | 3.41.8+ | https://flutter.dev/docs/get-started/install |
| Dart           | 3.11.5+ | Sudah termasuk dalam Flutter                 |
| Xcode          | 15+     | Mac App Store (untuk iOS)                    |
| Android Studio | 2023+   | https://developer.android.com/studio         |
| Chrome         | Terbaru | Untuk Flutter Web                            |

## Setup Awal (Sekali Saja)

### 1. Clone / buka project

```bash
cd pantau_pegawai
```

### 2. Buat file credentials (WAJIB)

File `lib/core/constants/supabase_constants.dart` sekarang membaca dari environment variables saat build — **tidak perlu dibuat manual**. Nilai diisi via `--dart-define` saat build atau via Vercel Environment Variables.

Untuk development lokal, jalankan dengan:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://glywzqbifjordhwulpbw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=GOOGLE_SHEETS_API_KEY=your_key \
  --web-browser-flag "--disable-web-security"
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Generate Riverpod code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 5. Jalankan SQL migration di Supabase

- Buka Supabase Dashboard → SQL Editor
- Jalankan `supabase/migrations/001_initial_schema.sql`
- Jalankan `supabase/migrations/002_dokumentasi_harian.sql`

### 6. Buat akun admin

- Supabase Dashboard → Authentication → Users → Add user
- Jalankan SQL:

```sql
UPDATE public.users
SET role = 'admin', nama = 'Administrator'
WHERE email = 'admin@instansi.go.id';
```

---

## Menjalankan Aplikasi

### Flutter Web (Admin Dashboard)

```bash
# Development (dengan CORS disabled untuk localhost)
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://glywzqbifjordhwulpbw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=GOOGLE_SHEETS_API_KEY=your_key \
  --web-browser-flag "--disable-web-security"
```

### Flutter iOS (Pegawai App)

```bash
# Install pods (sekali saja atau setelah update dependencies)
cd ios && pod install && cd ..

# Lihat device yang terhubung
flutter devices

# Jalankan ke iPhone
flutter run -d <device_id>
```

### Flutter Android

```bash
flutter run -d <device_id>
```

---

## Setelah Mengubah Kode

### Hot reload (perubahan UI)

Tekan `r` di terminal Flutter.

### Hot restart (perubahan provider/konstanta)

Tekan `R` di terminal Flutter.

### Full restart (perubahan yang tidak terdeteksi)

Stop (`q`) lalu jalankan ulang `flutter run`.

---

## Deploy Edge Functions

Setiap kali mengubah kode Edge Function:

**Via Browser (mudah):**

1. Supabase Dashboard → Edge Functions → klik nama function
2. Tab "Code" → edit → Deploy

**Via CLI:**

```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Login dengan personal access token dari:
# https://supabase.com/dashboard/account/tokens
supabase login --token sbp_xxx...

# Deploy
supabase functions deploy admin-create-user --project-ref glywzqbifjordhwulpbw
supabase functions deploy admin-delete-user --project-ref glywzqbifjordhwulpbw
supabase functions deploy admin-reset-password --project-ref glywzqbifjordhwulpbw
supabase functions deploy upload-to-drive --project-ref glywzqbifjordhwulpbw
supabase functions deploy image-proxy --project-ref glywzqbifjordhwulpbw
supabase functions deploy import-from-sheets --project-ref glywzqbifjordhwulpbw
```

---

## Build Production

### Web

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://glywzqbifjordhwulpbw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=GOOGLE_SHEETS_API_KEY=your_key
# Output: build/web/
```

Output berupa file HTML/CSS/JS statis di folder `build/web/` yang siap di-hosting.

#### Deploy ke Vercel (Production — Recommended)

Aplikasi web sudah dikonfigurasi untuk deploy otomatis ke Vercel via GitHub.

**Setup awal (sekali saja):**

1. Push repo ke GitHub
2. Buka [vercel.com](https://vercel.com) → New Project → Import repo
3. Vercel otomatis baca `vercel.json` — tidak perlu konfigurasi manual
4. Di **Settings → Environment Variables**, tambahkan:

| Name                    | Value                                      |
| ----------------------- | ------------------------------------------ |
| `SUPABASE_URL`          | `https://glywzqbifjordhwulpbw.supabase.co` |
| `SUPABASE_ANON_KEY`     | Legacy anon key (`eyJhbGci...`)            |
| `GOOGLE_SHEETS_API_KEY` | API key Google Sheets                      |

5. Klik Deploy

**Deploy selanjutnya:** Otomatis setiap `git push` ke branch `main`.

**File konfigurasi Vercel:**

- `vercel.json` — build command, output directory, SPA routing rewrite
- `build.sh` — install Flutter 3.41.8, enable web, pub get, build_runner, flutter build web

> ⚠️ Gunakan **Legacy anon key** (format `eyJhbGci...`), bukan Publishable key (format `sb_publishable_...`). Supabase Edge Functions hanya menerima legacy key.

### iOS (butuh Apple Developer Account)

```bash
flutter build ios --release
# Lalu buka Xcode untuk archive dan distribute
```

### Android

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Migrasi Data dari AppSheet (Sekali Jalan)

Untuk mengimpor data historis dari Google Spreadsheet lama ke Supabase:

```bash
# Install dependency (sekali saja)
npm install @supabase/supabase-js

# Jalankan migrasi
SUPABASE_SERVICE_ROLE_KEY=xxx node scripts/migrate-from-sheets.js
```

Script ini akan:

1. Membaca sheet `DOKUMENTASI HARIAN` dari spreadsheet AppSheet lama
2. Mencocokkan nama pegawai ke akun Supabase
3. Menginsert semua data ke tabel `dokumentasi`
4. URL foto Google Drive disimpan as-is ke `image_url` (tidak perlu upload ulang)

Lihat `scripts/migrate-from-sheets.js` untuk konfigurasi Spreadsheet ID dan mapping nama pegawai.

---

## Akun Default

| Role    | Email             | Password             |
| ------- | ----------------- | -------------------- |
| Admin   | admin@pawai.go.id | (sesuai yang dibuat) |
| Pegawai | als@bps.go.id     | (sesuai yang dibuat) |

> Ganti password setelah setup menggunakan fitur "Ubah Password" di halaman Edit Pegawai.
