# PantauPegawai — Dokumentasi Pengembangan

Dokumen ini merangkum seluruh tahapan pembangunan aplikasi **PantauPegawai** dari awal hingga MVP.

## Stack Teknologi

| Layer            | Teknologi                                       |
| ---------------- | ----------------------------------------------- |
| Mobile (Pegawai) | Flutter Android / iOS                           |
| Web (Admin)      | Flutter Web — deploy via Vercel                 |
| Auth & Database  | Supabase (PostgreSQL + RLS)                     |
| Realtime         | Supabase Realtime                               |
| File Storage     | Google Drive via Service Account                |
| Upload Proxy     | Supabase Edge Functions (Deno/TypeScript)       |
| State Management | Riverpod (riverpod_annotation)                  |
| Navigation       | go_router                                       |
| HTTP Client      | http package                                    |
| Image Picker     | image_picker (XFile/Uint8List — web compatible) |

## Daftar Dokumen

| File                              | Isi                                                                |
| --------------------------------- | ------------------------------------------------------------------ |
| `01-setup-project.md`             | Setup project Flutter, dependencies, struktur folder               |
| `02-database-schema.md`           | Schema database Supabase, RLS, trigger                             |
| `03-supabase-setup.md`            | Konfigurasi Supabase: Auth, API Keys, SQL migration                |
| `04-edge-functions.md`            | Semua Edge Functions yang di-deploy ke Supabase                    |
| `05-fitur-auth.md`                | Implementasi login/logout, role-based redirect                     |
| `06-fitur-pegawai.md`             | CRUD pegawai, ubah password                                        |
| `07-fitur-dokumentasi.md`         | Dokumentasi harian: upload foto, filter, riwayat, rekap upload     |
| `08-fitur-admin.md`               | Dashboard admin, CRUD kegiatan, assign, laporan, rekap upload      |
| `09-troubleshooting.md`           | Masalah yang ditemui dan solusinya (termasuk CORS & image-proxy)   |
| `10-cara-menjalankan.md`          | Panduan menjalankan dan deploy aplikasi (termasuk Vercel)          |
| `11-install-ios-android.md`       | Panduan install ke iPhone dan Android                              |
| `12-panduan-instalasi-lengkap.md` | **Panduan instalasi end-to-end** (Supabase + DB + Drive + Flutter) |

## Referensi Aplikasi Sebelumnya

Aplikasi ini menggantikan versi AppSheet yang bisa diakses di:

- https://s.bps.go.id/pantau_pegawai

## Git

- Repository diinisialisasi pada: 4 Mei 2026
- Initial commit: `db6efb0`
- 130 files, 11.619 baris kode
