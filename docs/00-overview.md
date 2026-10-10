# PantauPegawai — Dokumentasi Pengembangan

Dokumen ini merangkum seluruh tahapan pembangunan aplikasi **PantauPegawai** dari awal hingga MVP.

## Stack Teknologi

| Layer            | Teknologi                                       |
| ---------------- | ----------------------------------------------- |
| Mobile (Pegawai) | Flutter Android / iOS                           |
| Web (Admin)      | Flutter Web — deploy via Vercel                 |
| Database         | PostgreSQL 16 di VPS (Docker Compose)           |
| API & Auth       | Node.js + Fastify (folder `server/`), token sesi |
| File Storage     | Google Drive via Service Account                |
| Upload & Proxy   | Endpoint API `/api/uploads`, `/api/images`      |
| HTTPS            | Caddy (Let's Encrypt otomatis)                  |
| State Management | Riverpod (riverpod_annotation)                  |
| Navigation       | go_router                                       |
| HTTP Client      | http package                                    |
| Image Picker     | image_picker (XFile/Uint8List — web compatible) |

## Daftar Dokumen

| File                              | Isi                                                                |
| --------------------------------- | ------------------------------------------------------------------ |
| `01-setup-project.md`             | Setup project Flutter, dependencies, struktur folder               |
| `02-database-schema.md`           | Schema database (versi Supabase, struktur tabel masih sama)        |
| `03-supabase-setup.md`            | _(Lama)_ Konfigurasi Supabase                                      |
| `04-edge-functions.md`            | _(Lama)_ Edge Functions Supabase — kini diganti API `server/`      |
| `05-fitur-auth.md`                | Implementasi login/logout, role-based redirect                     |
| `06-fitur-pegawai.md`             | CRUD pegawai, ubah password                                        |
| `07-fitur-dokumentasi.md`         | Dokumentasi harian: upload foto, filter, riwayat, rekap upload     |
| `08-fitur-admin.md`               | Dashboard admin, CRUD kegiatan, assign, laporan, rekap upload      |
| `09-troubleshooting.md`           | Masalah yang ditemui dan solusinya (termasuk CORS & image-proxy)   |
| `10-cara-menjalankan.md`          | Menjalankan API & aplikasi secara lokal, build production          |
| `11-install-ios-android.md`       | Panduan install ke iPhone dan Android                              |
| `12-panduan-instalasi-lengkap.md` | _(Lama)_ Instalasi end-to-end versi Supabase                       |
| `13-deploy-vps.md`                | **Deploy ke VPS** (PostgreSQL + API + HTTPS), pindah data dari Supabase |

## Referensi Aplikasi Sebelumnya

Aplikasi ini menggantikan versi AppSheet yang bisa diakses di:

- https://s.bps.go.id/pantau_pegawai

## Git

- Repository diinisialisasi pada: 4 Mei 2026
- Initial commit: `db6efb0`
- 130 files, 11.619 baris kode
