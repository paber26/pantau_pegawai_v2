# PantauPegawai

Aplikasi monitoring pegawai berbasis Flutter + Supabase + Google Drive.

## Stack

| Layer               | Teknologi                        |
| ------------------- | -------------------------------- |
| Mobile (Pegawai)    | Flutter Android                  |
| Web/Desktop (Admin) | Flutter Web/Desktop              |
| Auth & Database     | Supabase (PostgreSQL + RLS)      |
| Realtime            | Supabase Realtime                |
| File Storage        | Google Drive via Service Account |
| Upload Proxy        | Supabase Edge Function (Deno)    |
| State Management    | Riverpod                         |
| Navigation          | go_router                        |

---

## Setup

### 1. Supabase

1. Buat project baru di [supabase.com](https://supabase.com)
2. Jalankan migration di **SQL Editor**:
   ```
   supabase/migrations/001_initial_schema.sql
   ```
3. Buat user admin pertama:
   - Pergi ke **Authentication > Users > Add User**
   - Masukkan email dan password admin
   - Jalankan SQL berikut untuk set role admin:
     ```sql
     UPDATE public.users
     SET role = 'admin', nama = 'Nama Admin', jabatan = 'Admin Sistem'
     WHERE email = 'admin@instansi.go.id';
     ```

### 2. Google Drive Service Account

1. Buka [Google Cloud Console](https://console.cloud.google.com)
2. Buat project baru atau gunakan yang sudah ada
3. Aktifkan **Google Drive API**
4. Buat **Service Account**:
   - IAM & Admin > Service Accounts > Create
   - Download JSON key
5. Buat folder di Google Drive bernama `PantauPegawai`
6. Share folder tersebut ke email service account dengan role **Editor**
7. Catat **Folder ID** dari URL Google Drive

### 3. Deploy Edge Function

```bash
# Install Supabase CLI
npm install -g supabase

# Login
supabase login

# Link ke project
supabase link --project-ref YOUR_PROJECT_ID

# Set secrets
supabase secrets set GOOGLE_SERVICE_ACCOUNT_EMAIL="your-sa@project.iam.gserviceaccount.com"
supabase secrets set GOOGLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n..."
supabase secrets set GOOGLE_DRIVE_ROOT_FOLDER_ID="your_folder_id"

# Deploy function
supabase functions deploy upload-to-drive
```

### 4. Flutter App

1. Update `lib/core/constants/supabase_constants.dart`:

   ```dart
   static const String url = 'https://YOUR_PROJECT_ID.supabase.co';
   static const String anonKey = 'YOUR_ANON_KEY';
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Generate Riverpod code:

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. Jalankan:

   ```bash
   # Android
   flutter run

   # Web
   flutter run -d chrome

   # Desktop (macOS/Windows/Linux)
   flutter run -d macos
   ```

---

## Struktur Project

```
lib/
├── core/           # Constants, theme, router, utils, errors
├── features/
│   ├── auth/       # Login, logout, session
│   ├── pegawai/    # CRUD pegawai
│   ├── kegiatan/   # CRUD kegiatan
│   ├── penugasan/  # Assign kegiatan ke pegawai
│   ├── laporan/    # Upload & lihat laporan
│   └── dashboard/  # Statistik admin
└── shared/
    └── widgets/    # Komponen UI reusable
```

---

## Permissions Android

Tambahkan ke `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

---

## Generate Riverpod Code

Setiap kali menambah provider baru dengan `@riverpod` annotation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Atau watch mode saat development:

```bash
dart run build_runner watch
```

---

## Catatan Keamanan

- **Jangan** commit `supabase_constants.dart` dengan credentials asli ke repository publik
- Gunakan environment variables atau `.env` file yang di-gitignore
- Google Service Account credentials **hanya** ada di Edge Function secrets, tidak pernah di client
- RLS aktif di semua tabel — pegawai tidak bisa akses data pegawai lain
