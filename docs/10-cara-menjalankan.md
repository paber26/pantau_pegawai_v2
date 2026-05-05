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

Buat file `lib/core/constants/supabase_constants.dart`:

```dart
class SupabaseConstants {
  SupabaseConstants._();

  static const String url = 'https://glywzqbifjordhwulpbw.supabase.co';
  static const String anonKey = 'eyJhbGci...'; // Legacy anon key dari Supabase
  static const String uploadDriveFunctionUrl =
      '$url/functions/v1/upload-to-drive';
}
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
flutter run -d chrome --web-browser-flag "--disable-web-security"

# Atau buat alias di ~/.zshrc:
alias flutter-web='flutter run -d chrome --web-browser-flag "--disable-web-security"'
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
flutter build web --release
# Output: build/web/
```

Output berupa file HTML/CSS/JS statis di folder `build/web/` yang siap di-hosting.

#### Cara Membuka Hasil Build Web

> ⚠️ **Jangan** buka `index.html` langsung dengan double-click atau via file path
> (`127.0.0.1:5500/build/web/index.html`). Flutter web butuh HTTP server yang
> serve dari root folder `build/web/`, bukan dari subfolder.

**Cara 1 — Python HTTP Server (paling mudah, sudah ada di Mac/Linux):**

```bash
cd build/web
python3 -m http.server 8080
```

Buka: `http://localhost:8080`

**Cara 2 — Flutter langsung (direkomendasikan untuk development):**

```bash
flutter run -d chrome --release
```

Flutter otomatis handle server dan buka Chrome.

**Cara 3 — VS Code Live Server (perlu konfigurasi tambahan):**

Live Server secara default serve dari root project, bukan dari `build/web/`.
Akibatnya semua asset (flutter.js, manifest.json, dll) gagal load dengan 404.

Fix: tambahkan ke `.vscode/settings.json`:

```json
{
  "liveServer.settings.root": "/build/web"
}
```

Setelah itu klik kanan `build/web/index.html` → **Open with Live Server**.
URL akan menjadi `127.0.0.1:5500/index.html` (tanpa prefix `build/web/`).

> Catatan: Live Server kurang ideal untuk Flutter web karena setiap rebuild
> kamu harus restart Live Server. Cara 2 lebih praktis untuk development.

#### Hosting Production

| Platform             | Cara                                                                          |
| -------------------- | ----------------------------------------------------------------------------- |
| **Netlify**          | Drag & drop folder `build/web/` ke https://netlify.com/drop                   |
| **Firebase Hosting** | `firebase init hosting` (public dir: `build/web`) → `firebase deploy`         |
| **Nginx/VPS**        | Copy `build/web/` ke `/var/www/html/`, tambahkan `try_files $uri /index.html` |

Setelah deploy, update di Supabase → **Authentication → URL Configuration**:

- **Site URL**: `https://domain-kamu.com`
- **Redirect URLs**: `https://domain-kamu.com/**`

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
