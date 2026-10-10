# PantauPegawai

Aplikasi monitoring pegawai berbasis Flutter + API PostgreSQL di VPS + Google Drive.

## Stack

| Layer               | Teknologi                                   |
| ------------------- | ------------------------------------------- |
| Mobile (Pegawai)    | Flutter Android / iOS                       |
| Web (Admin)         | Flutter Web, deploy di Vercel               |
| API                 | Node.js 22 + Fastify (folder `server/`)     |
| Database            | PostgreSQL 16 di VPS                        |
| Login               | Token sesi dari API (disimpan hash di DB)   |
| File Storage        | Google Drive via Service Account            |
| HTTPS               | Caddy (Let's Encrypt otomatis)              |
| Deploy server       | Docker Compose (`docker-compose.yml`)       |
| State Management    | Riverpod                                    |
| Navigation          | go_router                                   |

> Aplikasi ini sebelumnya memakai Supabase. Panduan pindah data dan
> peralihan ada di [`docs/13-deploy-vps.md`](docs/13-deploy-vps.md).

---

## Setup

### 1. Server (VPS)

Ringkasnya (detail lengkap di [`docs/13-deploy-vps.md`](docs/13-deploy-vps.md)):

```bash
git clone https://github.com/paber26/pantau_pegawai_v2.git
cd pantau_pegawai_v2
cp .env.example .env                                   # isi API_DOMAIN, POSTGRES_PASSWORD, dll.
mkdir -p secrets                                       # taruh JSON service account Google:
cp /path/ke/key.json secrets/google-service-account.json
docker compose up -d --build
docker compose exec api node dist/scripts/create-admin.js   # admin pertama (instalasi baru)
```

### 2. Google Drive Service Account

1. Buka [Google Cloud Console](https://console.cloud.google.com), aktifkan **Google Drive API**
2. Buat **Service Account** → tab Keys → Add key → **JSON**
3. Buat folder di Google Drive (mis. `PantauPegawai`), share ke email service account dengan role **Editor**
4. Isi `GOOGLE_DRIVE_ROOT_FOLDER_ID` di `.env` dengan ID folder tersebut

### 3. Flutter App

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Jalankan (URL API diberikan saat build/run)
flutter run -d chrome --dart-define=API_URL=https://api-pawai.toolkitbps.my.id
# atau pakai ./run_local.sh yang membaca API_URL dari file .env
```

Web di Vercel: set Environment Variable `API_URL` (dan `GOOGLE_SHEETS_API_KEY`).

Menjalankan API secara lokal untuk pengembangan: lihat
[`docs/10-cara-menjalankan.md`](docs/10-cara-menjalankan.md).

---

## Struktur Project

```
lib/                    # Aplikasi Flutter
├── core/
│   ├── network/        # ApiClient & SessionStore (login, token)
│   ├── constants/      # ApiConstants (API_URL), warna, teks
│   └── ...             # theme, router, utils, errors
├── features/
│   ├── auth/           # Login, logout, sesi
│   ├── pegawai/        # CRUD pegawai
│   ├── kegiatan/       # CRUD proyek/kegiatan
│   ├── penugasan/      # Assign kegiatan ke pegawai
│   ├── dokumentasi/    # Dokumentasi harian (foto, filter, riwayat)
│   ├── rekap_upload/   # Rekap upload per pegawai
│   ├── import_sheets/  # Import data dari Google Sheets
│   ├── laporan/        # Laporan (fitur lama)
│   └── dashboard/      # Statistik admin
└── shared/widgets/     # Komponen UI reusable

server/                 # API Node.js + PostgreSQL
├── migrations/         # Skema database (dijalankan otomatis saat start)
├── src/routes/         # Endpoint /api/... + aturan akses
├── scripts/            # Pindah data Supabase, sinkron Sheets, buat admin
└── test/               # Test API (vitest + PostgreSQL)

deploy/                 # Caddyfile & script backup
docker-compose.yml      # db + api + caddy + backup
```

---

## Permissions Android

Sudah ada di `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
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

- Aplikasi Flutter hanya menyimpan `API_URL` — tidak ada kredensial database di client
- Kredensial Google Service Account **hanya** ada di server (`secrets/`, tidak di-commit)
- Aturan akses ditegakkan API: pegawai hanya bisa mengubah/menghapus dokumentasinya
  sendiri, hanya admin yang bisa mengelola pegawai & proyek
- Database tidak dibuka ke internet; backup harian di folder `backups/` — salin ke luar VPS secara berkala
