# Implementation Plan: dokumentasi-rekap-enhancement

## Overview

Implementasi peningkatan fitur dokumentasi dan rekap upload pada aplikasi Flutter PantauPegawai. Perubahan mencakup: penambahan field join pada `DokumentasiModel`, method `getByYear` pada repository dokumentasi, fitur bulk import 65 proyek pada halaman admin Kegiatan, dan halaman baru Rekap Upload dengan breakdown per bulan dan filter tahun.

Urutan implementasi mengikuti dependency: model/domain layer → data layer → provider/notifier → UI layer → routing/navigasi.

## Tasks

- [x] 1. Perbarui DokumentasiModel dengan field join baru
  - Tambah field `pegawaiJabatan` dan `pegawaiUnitKerja` (keduanya `String?`) pada class `DokumentasiModel` di `lib/features/dokumentasi/domain/dokumentasi_model.dart`
  - Perbarui constructor untuk menerima kedua field baru
  - Perbarui `factory DokumentasiModel.fromMap` untuk membaca `users['jabatan']` dan `users['unit_kerja']` dari map join
  - _Requirements: 4.12_

- [x] 2. Tambah method `getByYear` pada DokumentasiRepository dan implementasinya
  - [x] 2.1 Tambah signature `Future<List<DokumentasiModel>> getByYear(int year)` pada abstract class `DokumentasiRepository` di `lib/features/dokumentasi/data/dokumentasi_repository.dart`
    - _Requirements: 4.3, 4.4, 4.5_
  - [x] 2.2 Implementasi `getByYear` pada `DokumentasiRepositoryImpl` di `lib/features/dokumentasi/data/dokumentasi_repository_impl.dart`
    - Query Supabase: `.from('dokumentasi').select('*, users(nama, jabatan, unit_kerja)').gte('tanggal_kegiatan', '$year-01-01').lte('tanggal_kegiatan', '$year-12-31').order('tanggal_kegiatan', ascending: false)`
    - Wrap dengan try/catch dan lempar `AppException` jika gagal
    - _Requirements: 4.3, 4.5_

- [x] 3. Buat model BulkImportResult
  - Buat file baru `lib/features/kegiatan/domain/bulk_import_result.dart`
  - Definisikan class `BulkImportResult` dengan field `final int inserted` dan `final int skipped`
  - Tambah `const` constructor
  - _Requirements: 3.6_

- [x] 4. Tambah method `bulkImport` pada KegiatanRepository dan implementasinya
  - [x] 4.1 Tambah signature `Future<BulkImportResult> bulkImport(List<String> judulList, DateTime deadline)` pada abstract class `KegiatanRepository` di `lib/features/kegiatan/data/kegiatan_repository.dart`
    - _Requirements: 3.3, 3.5_
  - [x] 4.2 Implementasi `bulkImport` pada `KegiatanRepositoryImpl` di `lib/features/kegiatan/data/kegiatan_repository_impl.dart`
    - Fetch semua judul kegiatan yang sudah ada dari tabel `kegiatan`
    - Filter `judulList` untuk mendapatkan hanya judul yang belum ada (idempotent)
    - Insert judul-judul baru dengan deadline yang diberikan
    - Kembalikan `BulkImportResult(inserted: newItems.length, skipped: judulList.length - newItems.length)`
    - Wrap dengan try/catch dan lempar `AppException` jika gagal
    - _Requirements: 3.3, 3.4, 3.5, 3.7_

- [x] 5. Checkpoint — Pastikan semua tests pass
  - Pastikan semua tests pass, tanyakan kepada user jika ada pertanyaan.

- [x] 6. Tambah method `bulkImport` pada KegiatanNotifier dan konstanta daftar proyek
  - [x] 6.1 Definisikan konstanta `const List<String> kProyekBulkImport` berisi 65 judul proyek di `lib/features/kegiatan/presentation/kegiatan_provider.dart` (atau file constants terpisah `lib/features/kegiatan/domain/proyek_constants.dart`)
    - Gunakan daftar 65 proyek persis seperti yang ada di design document
    - _Requirements: 3.3_
  - [x] 6.2 Tambah method `Future<BulkImportResult?> bulkImport()` pada `KegiatanNotifier` di `lib/features/kegiatan/presentation/kegiatan_provider.dart`
    - Panggil `kegiatanRepositoryProvider.bulkImport(kProyekBulkImport, DateTime(2026, 12, 31))`
    - Panggil `refresh()` setelah berhasil
    - Return `null` jika terjadi exception (error ditangani di UI)
    - _Requirements: 3.3, 3.4, 3.8_

- [x] 7. Perbarui KegiatanListScreen dengan tombol Import Proyek
  - Tambah `IconButton` dengan `icon: Icons.upload_outlined` dan `tooltip: 'Import Proyek'` di AppBar actions, hanya tampil jika `isAdmin == true`
  - Implementasi method `_showImportDialog(BuildContext context, WidgetRef ref)` yang menampilkan `AlertDialog` konfirmasi
  - Setelah konfirmasi, panggil `KegiatanNotifier.bulkImport()` dan tampilkan `SnackBar` dengan hasil (jumlah inserted dan skipped)
  - Tampilkan `SnackBar` error jika `bulkImport()` mengembalikan `null`
  - _Requirements: 3.1, 3.2, 3.6, 3.7, 3.8_

- [x] 8. Buat model RekapUploadModel
  - Buat file baru `lib/features/rekap_upload/domain/rekap_upload_model.dart`
  - Definisikan class `RekapUploadModel` dengan field: `userId`, `nama`, `jabatan?`, `unitKerja?`, `total`, `perBulan` (`Map<int, int>`)
  - Tambah `const` constructor
  - _Requirements: 4.3, 4.4, 4.12_

- [x] 9. Buat RekapUploadNotifier
  - Buat file baru `lib/features/rekap_upload/presentation/rekap_upload_provider.dart`
  - Definisikan `_UserAccumulator` helper class (private) dengan field `userId`, `nama`, `jabatan?`, `unitKerja?`, `total`, `perBulan`
  - Implementasi `RekapUploadNotifier extends _$RekapUploadNotifier` dengan `riverpod_annotation`
  - Field `_selectedYear` diinisialisasi dengan `DateTime.now().year`
  - Method `build()` memanggil `_fetchRekap(_selectedYear)`
  - Method `changeYear(int year)` memperbarui `_selectedYear` dan memanggil ulang `_fetchRekap`
  - Method `refresh()` memanggil ulang `_fetchRekap(_selectedYear)`
  - Method `_fetchRekap(int year)` memanggil `dokumentasiRepositoryProvider.getByYear(year)` lalu `_aggregate(docs)`
  - Method `_aggregate(List<DokumentasiModel> docs)` melakukan aggregasi client-side: group by `userId`, hitung `total` dan `perBulan`, sort descending by `total`
  - _Requirements: 4.3, 4.4, 4.5, 4.6, 4.8_

- [x] 10. Buat RekapUploadScreen
  - Buat file baru `lib/features/rekap_upload/presentation/rekap_upload_screen.dart`
  - Implementasi `RekapUploadScreen` sebagai `ConsumerWidget` yang meng-watch `rekapUploadNotifierProvider`
  - AppBar dengan `AdminMenuButton`, `AdminLogoutButton`, `_YearDropdown`, dan tombol refresh
  - `_YearDropdown`: dropdown tahun dari 2024 hingga `DateTime.now().year`, memanggil `notifier.changeYear(year)` saat berubah
  - State loading: tampilkan `LoadingShimmer`
  - State error: tampilkan `ErrorDisplay`
  - State data kosong: tampilkan widget `_EmptyRekap` dengan pesan informatif
  - State data ada: tampilkan `_GrandTotalBanner` di atas + `ListView.builder` dengan `_RekapCard`
  - `_GrandTotalBanner`: tampilkan total keseluruhan upload dan tahun yang dipilih
  - `_RekapCard`: tampilkan rank, nama pegawai (bold), jabatan, unit kerja, total upload (badge), dan horizontal scrollable row breakdown per bulan (Jan–Des)
  - Wrap `ListView` dengan `RefreshIndicator`
  - _Requirements: 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11, 4.12_

- [x] 11. Tambah nav item "Rekap Upload" di AdminScaffold
  - Tambah `_NavItem` baru di `_AdminSidebar` pada `lib/shared/widgets/admin_scaffold.dart`
  - Gunakan `icon: Icons.bar_chart_outlined`, `label: 'Rekap Upload'`, `route: '/admin/rekap-upload'`
  - `isActive: currentLocation.startsWith('/admin/rekap-upload')`
  - Tempatkan setelah nav item "Dokumentasi" dan sebelum "Import Data"
  - _Requirements: 4.1, 4.2_

- [x] 12. Tambah route `/admin/rekap-upload` di app_router.dart
  - Tambah `GoRoute` baru di dalam `ShellRoute` admin pada `lib/core/router/app_router.dart`
  - `path: '/admin/rekap-upload'`, `builder: (context, state) => const RekapUploadScreen()`
  - Tambah import `RekapUploadScreen`
  - Jalankan `dart run build_runner build --delete-conflicting-outputs` untuk regenerasi kode Riverpod
  - _Requirements: 4.2_

- [x] 13. Checkpoint — Pastikan semua tests pass
  - Pastikan semua tests pass, tanyakan kepada user jika ada pertanyaan.

- [x] 14. Tulis unit tests untuk logika filter DokumentasiScreen dan aggregasi RekapUpload
  - Buat file `test/features/dokumentasi/filter_logic_test.dart`
  - [x] 14.1 Unit test: filter by `userId` — list dengan berbagai userId, filter satu userId → semua hasil memiliki userId yang sama
    - _Requirements: 1.7_
  - [x] 14.2 Property test untuk filter proyek (Property 2)
    - **Property 2: Filter proyek hanya menampilkan dokumentasi yang proyeknya mengandung teks filter**
    - Generate random list `DokumentasiModel` dengan berbagai `proyek` dan random filter string → verifikasi semua hasil mengandung filter string (case-insensitive)
    - **Validates: Requirements 1.8**
  - [x] 14.3 Property test untuk filter tanggal (Property 3)
    - **Property 3: Filter tanggal hanya menampilkan dokumentasi dalam rentang yang dipilih**
    - Generate random list `DokumentasiModel` dengan berbagai `tanggalKegiatan` dan random date range → verifikasi semua hasil dalam rentang (inklusif)
    - **Validates: Requirements 1.9**
  - Buat file `test/features/rekap_upload/aggregate_test.dart`
  - [x] 14.4 Unit test: `_aggregate` dengan list kosong → hasil kosong
    - _Requirements: 4.3_
  - [x] 14.5 Unit test: `_aggregate` satu user, beberapa dokumentasi di bulan berbeda → `perBulan` benar dan `total` sesuai
    - _Requirements: 4.4_
  - [x] 14.6 Unit test: `_aggregate` beberapa user → diurutkan descending berdasarkan total
    - _Requirements: 4.8_
  - [x] 14.7 Property test untuk grand total dan per-bulan consistency (Property 7 & 8)
    - **Property 7: Grand total rekap sama dengan jumlah semua individual total**
    - **Property 8: Breakdown per bulan konsisten dengan total**
    - Generate random list `DokumentasiModel`, run `_aggregate` → verifikasi grand total dan sum(perBulan.values) == total untuk setiap item
    - **Validates: Requirements 4.7, 4.4**
  - [x] 14.8 Property test untuk urutan descending (Property 9)
    - **Property 9: Daftar rekap diurutkan descending berdasarkan total**
    - Generate random list `DokumentasiModel`, run `_aggregate` → verifikasi untuk setiap pasangan berurutan `list[i].total >= list[i+1].total`
    - **Validates: Requirements 4.8**

- [x] 15. Tulis unit tests untuk KegiatanRepository.bulkImport
  - Buat file `test/features/kegiatan/bulk_import_test.dart`
  - [x] 15.1 Unit test: semua proyek baru → `inserted == judulList.length`, `skipped == 0`
    - _Requirements: 3.3_
  - [x] 15.2 Unit test: beberapa proyek sudah ada → hanya yang baru diinsert, `skipped` sesuai
    - _Requirements: 3.5_
  - [x] 15.3 Unit test: semua proyek sudah ada → `inserted == 0`, `skipped == judulList.length`
    - _Requirements: 3.5_
  - [x] 15.4 Property test untuk idempotency bulkImport (Property 5)
    - **Property 5: Bulk import bersifat idempotent**
    - Simulasikan state awal kegiatan, run filter logic `bulkImport` dua kali → verifikasi count inserted pada run kedua selalu 0
    - **Validates: Requirements 3.5**
  - [x] 15.5 Property test untuk deadline (Property 6)
    - **Property 6: Semua proyek yang diimport memiliki deadline 31 Desember 2026**
    - Verifikasi bahwa setiap item yang akan diinsert memiliki deadline `DateTime(2026, 12, 31)`
    - **Validates: Requirements 3.4**

- [x] 16. Checkpoint akhir — Pastikan semua tests pass
  - Pastikan semua tests pass, tanyakan kepada user jika ada pertanyaan.

## Notes

- Tasks bertanda `*` bersifat opsional dan dapat dilewati untuk MVP yang lebih cepat
- Setiap task mereferensikan requirements spesifik untuk traceability
- Urutan task mengikuti dependency: domain → data → provider → UI → routing
- Property tests menggunakan library `glados` atau `fast_check` (Dart PBT) — tambahkan ke `dev_dependencies` di `pubspec.yaml` jika belum ada
- Setelah menambah provider baru dengan `riverpod_annotation`, jalankan `dart run build_runner build --delete-conflicting-outputs` untuk regenerasi file `.g.dart`
- `_UserAccumulator` adalah helper class private di dalam file `rekap_upload_provider.dart`, tidak perlu file terpisah
