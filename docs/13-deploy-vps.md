# Tahap 13 — Deploy ke VPS (Pengganti Supabase)

Sejak versi ini PantauPegawai **tidak lagi memakai Supabase**. Database,
login, dan semua fungsi server berjalan di VPS sendiri:

```
Web admin  https://pawai.toolkitbps.my.id  (tetap di Vercel, alamat tidak berubah)
Aplikasi Android / iOS
        │  keduanya memanggil API lewat HTTPS
        ▼
   https://api-pawai.toolkitbps.my.id → Caddy di VPS (HTTPS otomatis, Let's Encrypt)
        ▼
   API Node.js (folder server/)  ──►  Google Drive (foto, service account)
        ▼
   PostgreSQL 16  ──►  backup harian (folder backups/)
```

| Dulu (Supabase)                    | Sekarang (VPS)                                  |
| ---------------------------------- | ----------------------------------------------- |
| Database PostgreSQL Supabase       | PostgreSQL 16 di container `db`                 |
| Supabase Auth                      | Login API (`/api/auth/login`), token sesi 30 hari |
| Row Level Security (RLS)           | Aturan akses di kode API (`server/src/routes`)  |
| Edge Function `upload-to-drive`    | `POST /api/uploads`                             |
| Edge Function `image-proxy`        | `GET /api/images?id=...`                        |
| Edge Function `admin-*`            | `/api/users` (tambah, ubah, hapus, reset password) |
| Edge Function `import-from-sheets` | `POST /api/import`                              |
| Backup otomatis Supabase           | Container `backup` (pg_dump harian)             |

---

## 1. Yang perlu disiapkan

| Kebutuhan | Keterangan |
| --- | --- |
| VPS | Ubuntu 22.04/24.04, minimal 1 vCPU, 2 GB RAM, 20 GB disk |
| Subdomain API | `api-pawai.toolkitbps.my.id` → **A record** ke IP VPS, dibuat **sebelum** menjalankan server (lihat *DNS untuk subdomain API* di bawah). Web admin tetap di `pawai.toolkitbps.my.id` (Vercel) |
| File JSON service account Google | Service account **yang sama** dengan yang dipakai Edge Function Supabase (punya akses ke folder Drive foto) |
| ID folder Google Drive | Nilai `GOOGLE_DRIVE_ROOT_FOLDER_ID` yang lama |
| Connection string database Supabase | Hanya untuk memindahkan data lama (langkah 5) |

### File JSON service account

Di Supabase dulu disimpan sebagai dua secret (`GOOGLE_SERVICE_ACCOUNT_EMAIL`
dan `GOOGLE_PRIVATE_KEY`). Sekarang dipakai dalam bentuk file JSON:

- **Cara 1 (disarankan):** Google Cloud Console → IAM & Admin → Service Accounts
  → pilih service account → tab **Keys** → Add key → JSON → download.
- **Cara 2:** buat file JSON sendiri dari dua nilai lama:

  ```json
  {
    "client_email": "nama-sa@project.iam.gserviceaccount.com",
    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIE...\n-----END PRIVATE KEY-----\n"
  }
  ```

> Pastikan folder Drive foto tetap di-share ke email service account tersebut
> dengan role **Editor**.

### DNS untuk subdomain API

Di tempat DNS `toolkitbps.my.id` dikelola (registrar / Cloudflare), tambahkan:

| Type | Name | Value | Keterangan |
| --- | --- | --- | --- |
| `A` | `api-pawai` | IP publik VPS | Bila memakai Cloudflare: set **DNS only** (awan abu-abu) agar Caddy bisa memasang sertifikat HTTPS sendiri |

Record `pawai` yang mengarah ke Vercel **jangan diubah**. Cek dari komputer
Anda: `nslookup api-pawai.toolkitbps.my.id` harus menampilkan IP VPS.

---

## 2. Instal Docker & firewall (sekali saja)

```bash
# Login ke VPS
ssh root@IP_VPS

# Docker + Docker Compose
curl -fsSL https://get.docker.com | sh

# Firewall: hanya SSH, HTTP, HTTPS
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443/tcp && ufw enable
```

> Database sengaja tidak dibuka ke internet (tidak ada `ports:` untuk `db`
> di `docker-compose.yml`).

> **VPS yang sudah menjalankan layanan lain:** cek dulu `docker --version`,
> `docker compose version`, dan `sudo ufw status`. Jangan instal ulang Docker,
> dan jangan `ufw enable` sebelum port layanan lain ikut dibuka — layanan itu
> bisa ikut terblokir.

---

## 3. Pasang aplikasi server

```bash
git clone https://github.com/paber26/pantau_pegawai_v2.git
cd pantau_pegawai_v2

# Konfigurasi
cp .env.example .env
nano .env
```

Isi `.env`:

| Variabel | Contoh | Keterangan |
| --- | --- | --- |
| `API_DOMAIN` | `api-pawai.toolkitbps.my.id` | Domain API (DNS sudah mengarah ke VPS) |
| `CORS_ORIGINS` | `https://pawai.toolkitbps.my.id,https://pantau-pegawai-v2.vercel.app,http://localhost:*` | Domain web admin yang boleh memanggil API, pisahkan koma |
| `POSTGRES_PASSWORD` | hasil `openssl rand -hex 24` | Huruf & angka saja |
| `GOOGLE_DRIVE_ROOT_FOLDER_ID` | `1AbC...` | ID folder Drive foto (sama seperti dulu) |
| `GOOGLE_SHEETS_API_KEY` | `AIza...` | Untuk `./sync.sh` (opsional) |
| `APP_TIMEZONE` | `Asia/Makassar` | Zona waktu "hari ini" di dashboard |
| `BACKUP_KEEP_DAYS` | `7` | Lama backup harian disimpan |

Taruh file service account:

```bash
mkdir -p secrets && chmod 700 secrets
nano secrets/google-service-account.json     # tempel isi JSON
chmod 644 secrets/google-service-account.json  # agar bisa dibaca container
```

Cek dulu siapa yang memegang port 80/443:

```bash
sudo ss -tlnp '( sport = :80 or sport = :443 )'
```

- **Kosong** → jalankan apa adanya (Caddy di `docker-compose.yml` memasang HTTPS otomatis):

  ```bash
  docker compose up -d --build
  docker compose ps                       # semua service harus "running"/"healthy"
  curl https://api-pawai.toolkitbps.my.id/health   # → {"status":"ok"}
  ```

- **Sudah dipakai nginx** (VPS yang menjalankan situs lain) → ikuti bagian berikut.

Saat pertama start, API otomatis membuat tabel (folder `server/migrations/`).

### VPS yang sudah memakai nginx (port 80/443 terpakai)

Caddy tidak dijalankan; API dibuka hanya di `127.0.0.1` lalu di-proxy oleh
nginx yang sudah ada. Vhost lain tidak disentuh.

1. Override compose (file ini tidak ikut git):

   ```bash
   cp docker-compose.override.example.yml docker-compose.override.yml
   sudo ss -tlnp | grep ':3102 '    # harus kosong; bila terpakai, ganti port di override
   docker compose up -d --build     # hanya db, api, backup
   curl -s http://127.0.0.1:3102/health   # → {"status":"ok"}
   ```

2. Vhost nginx baru khusus API (contoh: `deploy/nginx-api-pawai.conf`):

   ```bash
   sudo cp deploy/nginx-api-pawai.conf /etc/nginx/sites-available/api-pawai
   sudo ln -s /etc/nginx/sites-available/api-pawai /etc/nginx/sites-enabled/api-pawai
   sudo nginx -t && sudo systemctl reload nginx     # reload, bukan restart
   sudo certbot --nginx -d api-pawai.toolkitbps.my.id --redirect
   ```

   Tanpa vhost ini, nginx menjawab domain API dengan situs **lain** (vhost
   pertama yang mendengar 443): `/health` menampilkan halaman aplikasi lain
   dan sertifikat tidak valid.

3. Verifikasi dari luar (laptop) dan dari server:

   ```bash
   curl -s https://api-pawai.toolkitbps.my.id/health     # → {"status":"ok"}, gembok valid
   curl -si -X OPTIONS https://api-pawai.toolkitbps.my.id/api/auth/login \
     -H 'Origin: https://pawai.toolkitbps.my.id' -H 'Access-Control-Request-Method: POST' \
     | grep -i access-control-allow-origin     # → https://pawai.toolkitbps.my.id
   ```

---

## 4. Akun admin pertama

**Lewati langkah ini bila Anda memindahkan data dari Supabase** (langkah 5),
karena akun admin lama ikut dipindah.

Untuk instalasi baru:

```bash
docker compose exec api node dist/scripts/create-admin.js
# Email admin: admin@bps.go.id
# Nama: Administrator
# Password baru: ********
```

Script yang sama dipakai untuk **memulihkan admin yang lupa password**
(isi email yang sudah ada, kosongkan nama).

> Script ini selalu menjadikan akun tersebut **admin**. Untuk pegawai yang lupa
> password, reset lewat web: login sebagai admin → menu **Pegawai** → Reset Password.

---

## 5. Pindahkan data dari Supabase

Semua tabel dipindah dengan ID yang sama. **Password lama tetap berlaku**
(hash password diambil dari Supabase Auth). URL foto otomatis diarahkan ke
API baru.

1. Ambil connection string: Supabase Dashboard → tombol **Connect** → tab
   **Direct (Connection string)** → Method **Session pooler** (IPv4, port
   **5432**; bukan Direct connection maupun Transaction pooler 6543). Bentuknya:
   `postgresql://postgres.<ref>:<password-db>@aws-1-<region>.pooler.supabase.com:5432/postgres`
   - Ganti `[YOUR-PASSWORD]` **termasuk tanda kurung sikunya** dengan password database.
   - Karakter khusus di password harus ditulis dalam kode URL:
     `@` → `%40`, `#` → `%23`, `/` → `%2F`, `:` → `%3A`
     (contoh: password `@Rahasia1` ditulis `%40Rahasia1`).
   - Berikan URL ini langsung di terminal VPS, jangan ditempel ke chat.
     Setelah migrasi selesai, reset password database di Supabase.
2. Latihan dulu (tidak ada yang disimpan):

   ```bash
   docker compose exec -e SUPABASE_DB_URL='postgresql://...' \
     api node dist/scripts/migrate-from-supabase.js --dry-run
   ```

3. Jika laporan terlihat benar, jalankan sungguhan:

   ```bash
   docker compose exec -e SUPABASE_DB_URL='postgresql://...' \
     api node dist/scripts/migrate-from-supabase.js
   ```

Contoh laporan:

```
Jumlah baris (Supabase → VPS):
  users             26 →      26
  kegiatan          41 →      41
  penugasan          0 →       0
  laporan            3 →       3
  dokumentasi     4210 →    4210

URL gambar yang diganti ke API baru: 812

⚠ 1 user tanpa password (perlu reset oleh admin):
  - contoh@bps.go.id
```

Catatan:
- Script **menolak** menimpa database yang sudah berisi. Untuk mengulang dari
  awal (mis. saat hari-H), tambahkan `--force`.
- Bila muncul pesan *"Skema Supabase berbeda"*, ada kolom tambahan di Supabase
  yang tidak dikenal. Jika kolom itu memang tidak dipakai, tambahkan
  `--ignore-extra-columns`.
- Semua pengguna perlu login ulang satu kali di aplikasi baru.

---

## 6. Arahkan aplikasi ke API baru

### Web admin (Vercel)

Web admin tetap di **https://pawai.toolkitbps.my.id**; yang diganti hanya
alamat API yang dipanggilnya. Vercel → Project → **Settings → Environment Variables**:

| Hapus | Tambah |
| --- | --- |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | `API_URL` = `https://api-pawai.toolkitbps.my.id` |

`GOOGLE_SHEETS_API_KEY` tetap. Lalu **Redeploy**. Pastikan
`https://pawai.toolkitbps.my.id` tercantum di `CORS_ORIGINS` pada `.env` VPS
(ubah → `docker compose up -d`).

> Isi `API_URL` **setelah** `https://api-pawai.toolkitbps.my.id/health`
> menjawab `{"status":"ok"}`. Selama `API_URL` belum diisi, build Vercel
> sengaja gagal dan versi lama tetap tayang di `pawai.toolkitbps.my.id`.

### Android / iOS

Build ulang dengan `API_URL`:

```bash
flutter build apk --release --dart-define=API_URL=https://api-pawai.toolkitbps.my.id
flutter build ios --release --dart-define=API_URL=https://api-pawai.toolkitbps.my.id
```

Aplikasi versi lama (yang masih ke Supabase) tidak akan bisa dipakai lagi
setelah Supabase dihentikan — bagikan APK/iOS baru ke pegawai.

---

## 7. Checklist hari-H peralihan

1. Umumkan ke pegawai: selama peralihan (±30 menit) pakai **versi web**.
2. Bekukan penulisan di Supabase agar tidak ada data yang tertinggal —
   Supabase Dashboard → SQL Editor:

   ```sql
   REVOKE INSERT, UPDATE, DELETE
     ON public.users, public.kegiatan, public.penugasan, public.laporan, public.dokumentasi
     FROM authenticated;
   ```

3. Pindahkan data final:
   `docker compose exec -e SUPABASE_DB_URL='...' api node dist/scripts/migrate-from-supabase.js --force`
4. Set `API_URL` di Vercel → Redeploy.
5. Uji (lihat langkah 8).
6. Bagikan APK/iOS baru.
7. Setelah semua stabil (mis. 1–2 minggu): **Pause** project Supabase, lalu
   hapus folder `supabase/` dari repository.

> Rollback darurat: kembalikan env Vercel ke `SUPABASE_URL`/`SUPABASE_ANON_KEY`
> lama, redeploy versi sebelumnya, dan jalankan
> `GRANT INSERT, UPDATE, DELETE ON ... TO authenticated;` di Supabase.

---

## 8. Uji setelah pindah

- [ ] Login admin & pegawai dengan **password lama**
- [ ] Dashboard: angka pegawai, proyek, dokumentasi sesuai (tidak lagi mentok 1000)
- [ ] Daftar dokumentasi tampil lengkap, **foto lama tampil**
- [ ] Tambah dokumentasi dengan foto → foto muncul, dan di Google Drive ada
      file baru di folder `{nama pegawai}/{tanggal}`
- [ ] Edit & hapus dokumentasi
- [ ] Rekap Upload, Kelola Pegawai (tambah, edit, reset password)
- [ ] Refresh halaman web tetap di halaman yang sama (tidak kembali ke login)

---

## 9. Operasional sehari-hari

| Kebutuhan | Perintah (di folder repository pada VPS) |
| --- | --- |
| Update aplikasi server | `git pull && docker compose up -d --build` |
| Lihat log API | `docker compose logs -f api` |
| Status service | `docker compose ps` |
| Sinkron data dari Spreadsheet AppSheet | `./sync.sh` |
| Hapus dokumentasi duplikat | `docker compose exec api node dist/scripts/cleanup-duplicates.js --dry-run` (hapus `--dry-run` untuk eksekusi) |
| Reset password admin | `docker compose exec api node dist/scripts/create-admin.js` |
| Reset password pegawai | Web, login sebagai admin → menu **Pegawai** → Reset Password |
| Masuk ke database | `docker compose exec db psql -U pantau pantau` |

### Backup & restore

Backup harian tersimpan di folder `backups/` (format `pantau_YYYYmmdd_HHMMSS.dump`).
**Salin secara berkala ke luar VPS**, misalnya dari komputer kantor:

```bash
rsync -avz root@IP_VPS:/root/pantau_pegawai_v2/backups/ ./backup-pantau/
```

Restore (menimpa isi database):

```bash
docker compose cp backups/pantau_20261010_020000.dump db:/tmp/restore.dump
docker compose exec db pg_restore -U pantau -d pantau --clean --if-exists /tmp/restore.dump
```

---

## 10. Troubleshooting

| Gejala | Penyebab & solusi |
| --- | --- |
| HTTPS gagal / `curl` error sertifikat | DNS belum mengarah ke VPS, atau port 80/443 tertutup. Cek `docker compose logs caddy` |
| Web admin: error CORS | Domain Vercel belum ada di `CORS_ORIGINS` → ubah `.env`, `docker compose up -d` |
| Foto tidak tampil / upload error 503 | File `secrets/google-service-account.json` tidak ada/salah, atau `GOOGLE_DRIVE_ROOT_FOLDER_ID` kosong |
| Upload error "Drive" 403/404 | Folder Drive belum di-share ke email service account (role Editor) |
| `docker compose up` error `secret ... not found` | File `secrets/google-service-account.json` belum dibuat |
| Semua pengguna "Sesi tidak valid" | Wajar sekali setelah pindah: login ulang |
| Lupa password admin | `docker compose exec api node dist/scripts/create-admin.js` |
| `https://api-.../health` menampilkan situs/login aplikasi lain, sertifikat "Not Secure" | Nginx belum punya vhost untuk domain API → ikuti bagian *VPS yang sudah memakai nginx* |
| Web: "Tidak dapat terhubung ke server" | API tidak terjangkau dari luar atau CORS ditolak. Cek `/health` dari laptop dan preflight CORS (bagian 3) |
| Login: "Email atau kata sandi salah" padahal benar | Data belum dipindah (tabel `users` kosong): `docker compose exec -T db psql -U pantau pantau -c "select count(*) from users"` |

---

## 11. Keamanan

- API key Google Sheets lama sempat tertulis di kode (`scripts/migrate-from-sheets.js`)
  dan masih ada di riwayat git. **Buat key baru / batasi key lama** di Google
  Cloud Console (APIs & Services → Credentials), lalu isi `GOOGLE_SHEETS_API_KEY`.
- File `.env`, `secrets/`, dan `backups/` tidak boleh di-commit (sudah ada di `.gitignore`).
- Token login disimpan di database dalam bentuk hash; logout, reset password,
  dan hapus pegawai langsung mematikan sesi di semua perangkat.
