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
```

---

## Build Production

### Web

```bash
flutter build web --release
# Output: build/web/
```

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

## Akun Default

| Role    | Email             | Password             |
| ------- | ----------------- | -------------------- |
| Admin   | admin@pawai.go.id | (sesuai yang dibuat) |
| Pegawai | als@bps.go.id     | (sesuai yang dibuat) |

> Ganti password setelah setup menggunakan fitur "Ubah Password" di halaman Edit Pegawai.
