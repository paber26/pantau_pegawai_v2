# Implementation Tasks: PantauPegawai

## Status: MVP Selesai ✅

---

## Phase 1: Setup & Infrastructure

- [x] **Task 1.1** — Buat struktur project Flutter (feature-based clean architecture)
- [x] **Task 1.2** — Konfigurasi `pubspec.yaml` dengan semua dependencies
- [x] **Task 1.3** — Setup tema, warna, dan konstanta aplikasi
- [x] **Task 1.4** — Setup go_router dengan redirect berbasis role
- [x] **Task 1.5** — Buat Supabase migration SQL (schema + RLS + trigger)

---

## Phase 2: Authentication

- [x] **Task 2.1** — `AuthRepository` + `AuthRepositoryImpl` (login, logout, session)
- [x] **Task 2.2** — `AuthProvider` dengan Riverpod (`authStateProvider`, `AuthNotifier`)
- [x] **Task 2.3** — `LoginScreen` UI (email + password, validasi, loading state)
- [x] **Task 2.4** — Auto-redirect berdasarkan role (admin → dashboard, pegawai → kegiatan)

---

## Phase 3: Manajemen Pegawai (Admin)

- [x] **Task 3.1** — `PegawaiModel` domain model
- [x] **Task 3.2** — `PegawaiRepository` + `PegawaiRepositoryImpl` (CRUD + Supabase Admin API)
- [x] **Task 3.3** — `PegawaiNotifier` provider
- [x] **Task 3.4** — `PegawaiListScreen` dengan card, popup menu edit/hapus
- [x] **Task 3.5** — `PegawaiFormScreen` untuk tambah dan edit pegawai

---

## Phase 4: Manajemen Kegiatan (Admin + Pegawai)

- [x] **Task 4.1** — `KegiatanModel` domain model
- [x] **Task 4.2** — `KegiatanRepository` + `KegiatanRepositoryImpl`
- [x] **Task 4.3** — `KegiatanNotifier` + `myKegiatanProvider`
- [x] **Task 4.4** — `KegiatanListScreen` (shared untuk admin dan pegawai)
- [x] **Task 4.5** — `KegiatanFormScreen` dengan date picker deadline
- [x] **Task 4.6** — `KegiatanDetailScreen` untuk pegawai

---

## Phase 5: Penugasan

- [x] **Task 5.1** — `PenugasanModel` domain model
- [x] **Task 5.2** — `PenugasanRepository` + `PenugasanRepositoryImpl`
- [x] **Task 5.3** — `PenugasanNotifier` provider
- [x] **Task 5.4** — `AssignScreen` dengan checkbox list pegawai

---

## Phase 6: Upload Laporan

- [x] **Task 6.1** — `LaporanModel` domain model
- [x] **Task 6.2** — `LaporanRepository` + `LaporanRepositoryImpl` (upload via Edge Function)
- [x] **Task 6.3** — `LaporanProvider` (admin list, my laporan, upload notifier)
- [x] **Task 6.4** — `UploadLaporanScreen` (kamera/galeri, preview foto, deskripsi)
- [x] **Task 6.5** — `LaporanListScreen` (shared admin/pegawai, filter tanggal)
- [x] **Task 6.6** — `LaporanDetailScreen` (foto, info, buka di Google Drive)

---

## Phase 7: Dashboard Admin

- [x] **Task 7.1** — `DashboardStatsModel`
- [x] **Task 7.2** — `dashboardStatsProvider` (query paralel)
- [x] **Task 7.3** — `recentLaporanProvider` (Supabase Realtime stream)
- [x] **Task 7.4** — `AdminDashboardScreen` (stat cards + laporan terbaru realtime)

---

## Phase 8: Navigation & Scaffolds

- [x] **Task 8.1** — `AdminScaffold` (sidebar responsive: wide = persistent, narrow = drawer)
- [x] **Task 8.2** — `PegawaiScaffold` (bottom navigation bar)
- [x] **Task 8.3** — Shared widgets: `AppButton`, `AppTextField`, `StatCard`, `ErrorDisplay`, `LoadingShimmer`, `ConfirmDialog`

---

## Phase 9: Google Drive Integration

- [x] **Task 9.1** — Supabase Edge Function `upload-to-drive` (Deno/TypeScript)
  - JWT signing untuk Google Service Account
  - Buat folder otomatis: `/PantauPegawai/{nama}/{yyyy-mm-dd}/`
  - Upload file dengan multipart
  - Set permission public (anyone with link)
  - Return `image_url`

---

## Langkah Selanjutnya (Post-MVP)

- [ ] Notifikasi push saat laporan baru masuk (admin)
- [ ] Export laporan ke PDF/Excel
- [ ] Pagination infinite scroll untuk daftar laporan
- [ ] Offline support dengan local cache
- [ ] Dark mode
- [ ] Unit tests dan widget tests
