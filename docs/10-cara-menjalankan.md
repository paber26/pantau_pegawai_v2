# Tahap 10 — Cara Menjalankan Aplikasi

> Sejak pindah dari Supabase, aplikasi terdiri dari **API server** (folder
> `server/`, Node.js + PostgreSQL) dan **aplikasi Flutter**. Deploy ke VPS
> dijelaskan di [`13-deploy-vps.md`](13-deploy-vps.md).

## Prasyarat

| Tool           | Versi   | Cara Install                                 |
| -------------- | ------- | -------------------------------------------- |
| Flutter        | 3.41.8+ | https://flutter.dev/docs/get-started/install |
| Dart           | 3.11.5+ | Sudah termasuk dalam Flutter                 |
| Node.js        | 22+     | https://nodejs.org                           |
| Docker         | Terbaru | https://docs.docker.com/get-docker (untuk PostgreSQL lokal) |
| Xcode          | 15+     | Mac App Store (untuk iOS)                    |
| Android Studio | 2023+   | https://developer.android.com/studio         |
| Chrome         | Terbaru | Untuk Flutter Web                            |

---

## 1. Jalankan API secara lokal

```bash
# PostgreSQL lokal (sekali saja)
docker run -d --name pantau-db -e POSTGRES_PASSWORD=dev -p 5432:5432 postgres:16

cd server
npm install

export DATABASE_URL=postgres://postgres:dev@localhost:5432/postgres
export PUBLIC_API_URL=http://localhost:3000
export CORS_ORIGINS='http://localhost:*'
# Opsional, untuk upload & tampil foto:
# export GOOGLE_SERVICE_ACCOUNT_FILE=/path/ke/service-account.json
# export GOOGLE_DRIVE_ROOT_FOLDER_ID=xxxx

npm run dev            # API di http://localhost:3000 (tabel dibuat otomatis)
```

Buat akun admin (terminal lain, dengan `DATABASE_URL` yang sama):

```bash
cd server && npm run create-admin
```

Test server (butuh PostgreSQL; default `postgres://postgres@localhost:5433/pantau_test`,
ubah lewat `TEST_DATABASE_URL`):

```bash
cd server
npm run typecheck
TEST_DATABASE_URL=postgres://postgres:dev@localhost:5432/pantau_test npm test
```

---

## 2. Jalankan aplikasi Flutter

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate Riverpod
```

Buat `.env` di root repository (salin dari `.env.example`) dan isi:

```
API_URL=http://localhost:3000
GOOGLE_SHEETS_API_KEY=xxx   # opsional, untuk menu Import Data
```

Lalu:

```bash
./run_local.sh            # Chrome
./run_local.sh macos      # desktop macOS
./run_local.sh <device>   # HP (lihat: flutter devices)
```

Atau langsung:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

> **HP / emulator Android:** `localhost` di HP bukan komputer Anda. Pakai
> IP komputer di jaringan yang sama (mis. `http://192.168.1.10:3000`) atau
> `http://10.0.2.2:3000` untuk emulator. Android memblokir HTTP biasa
> secara default, jadi untuk HP paling mudah memakai API yang sudah HTTPS
> (API di VPS).

---

## Setelah Mengubah Kode

| Perubahan | Tindakan |
| --- | --- |
| UI Flutter | Tekan `r` (hot reload) |
| Provider/konstanta Flutter | Tekan `R` (hot restart) |
| Provider dengan `@riverpod` baru | `dart run build_runner build --delete-conflicting-outputs` |
| Kode API (`server/src`) | `npm run dev` otomatis restart |
| Struktur database | Tambah file baru `server/migrations/00N_nama.sql` (jalan otomatis saat API start) |

---

## Build Production

### Web (Vercel)

Deploy otomatis setiap `git push` ke branch `main` (lihat `vercel.json` dan
`build.sh`). Environment Variables di Vercel:

| Name                    | Value                                   |
| ----------------------- | --------------------------------------- |
| `API_URL`               | `https://api-pawai.toolkitbps.my.id`       |
| `GOOGLE_SHEETS_API_KEY` | API key Google Sheets                   |

Build manual:

```bash
flutter build web --release \
  --dart-define=API_URL=https://api-pawai.toolkitbps.my.id \
  --dart-define=GOOGLE_SHEETS_API_KEY=your_key
# Output: build/web/
```

### Android

```bash
flutter build apk --release --dart-define=API_URL=https://api-pawai.toolkitbps.my.id
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS (butuh Apple Developer Account)

```bash
cd ios && pod install && cd ..
flutter build ios --release --dart-define=API_URL=https://api-pawai.toolkitbps.my.id
# Lalu buka Xcode untuk archive dan distribute
```

### API server

Lihat [`13-deploy-vps.md`](13-deploy-vps.md) (Docker Compose di VPS).

---

## Sinkronisasi Data dari AppSheet

Untuk mengambil data dari Google Spreadsheet AppSheet lama ke database:

```bash
# Di VPS (memakai container api)
./sync.sh

# Atau lokal
cd server
DATABASE_URL=... GOOGLE_SHEETS_API_KEY=... npm run sync:sheets
```

Script (`server/scripts/migrate-from-sheets.ts`) membaca sheet
`DOKUMENTASI HARIAN`, mencocokkan nama pegawai ke akun, lalu menyimpan baris
yang belum ada ke tabel `dokumentasi`. Aman dijalankan berulang kali.
Mapping nama pegawai ada di bagian atas file script tersebut.
