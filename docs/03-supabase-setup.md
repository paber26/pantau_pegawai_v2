# Tahap 3 — Konfigurasi Supabase

## 3.1 Membuat Project Supabase

1. Buka https://supabase.com dan login
2. Klik **New project**
3. Isi:
   - **Organization**: nama organisasi
   - **Project name**: pantau-pegawai (atau sesuai kebutuhan)
   - **Database password**: buat password yang kuat
   - **Region**: Asia Pacific (Singapore) — terdekat dengan Indonesia
4. Klik **Create new project**, tunggu ~2 menit

## 3.2 Mendapatkan API Keys

Buka: **Settings → API Keys**

Ada dua jenis key:

### Publishable Key (format baru)

```
sb_publishable_xxxxx...
```

⚠️ Format ini **tidak kompatibel** dengan `supabase_flutter ^2.x`. Gunakan Legacy key.

### Legacy Anon Key ✅ (yang digunakan)

Klik tab **"Legacy anon, service_role API keys"**:

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6...
```

### Service Role Key (untuk Edge Functions)

Juga ada di tab Legacy. **JANGAN** gunakan di client Flutter.

## 3.3 Mengisi Credentials di Flutter

Edit file `lib/core/constants/supabase_constants.dart`:

```dart
class SupabaseConstants {
  static const String url = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String anonKey = 'eyJhbGci...'; // Legacy anon key
  static const String uploadDriveFunctionUrl =
      '$url/functions/v1/upload-to-drive';
}
```

> File ini ada di `.gitignore` — tidak boleh di-commit ke repository.

## 3.4 Project ID

Project ID bisa dilihat dari URL dashboard:

```
supabase.com/dashboard/project/YOUR_PROJECT_ID/...
```

Atau dari JWT payload anon key (field `ref`).

## 3.5 Edge Function Secrets

Buka: **Edge Functions → Secrets**

Tambahkan secret berikut:

| Name                           | Value                                 | Keterangan                  |
| ------------------------------ | ------------------------------------- | --------------------------- |
| `SERVICE_ROLE_KEY`             | `eyJhbGci...` (service role)          | Untuk admin operations      |
| `GOOGLE_SERVICE_ACCOUNT_EMAIL` | `xxx@project.iam.gserviceaccount.com` | Untuk upload Google Drive   |
| `GOOGLE_PRIVATE_KEY`           | `-----BEGIN PRIVATE KEY-----\n...`    | Private key service account |
| `GOOGLE_DRIVE_ROOT_FOLDER_ID`  | `1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs`   | ID folder root di Drive     |

> **Catatan:** Nama secret tidak boleh diawali `SUPABASE_` — itu prefix reserved.

## 3.6 CORS

Supabase tidak lagi menyediakan pengaturan CORS di dashboard (dihapus di versi terbaru). CORS dihandle di kode Edge Function masing-masing dengan header:

```typescript
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Authorization, Content-Type"
}
```

Saat development di localhost, jalankan Flutter dengan:

```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

Di production (iOS/Android/hosting), CORS tidak menjadi masalah.
