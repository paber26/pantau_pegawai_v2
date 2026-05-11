# Implementation Plan: App Enhancement — Proyek & Cache

## Overview

Implementasi serangkaian peningkatan independen pada aplikasi Flutter `pantau_pegawai_v2`:
image caching, rename sidebar Kegiatan → Proyek, pembaruan dashboard admin, dropdown proyek
di form dokumentasi, tombol Copy Link, dan integrasi Logo BPS sebagai launcher icon.
Semua perubahan berada di Presentation dan Provider layer (Flutter + Riverpod + Supabase).

## Tasks

- [-] 1. Tambah image caching di `DriveImage` widget
  - Di `lib/shared/widgets/drive_image.dart`, tambahkan import `package:cached_network_image/cached_network_image.dart`
  - Ganti `Image.network(proxyUrl, ...)` dengan `CachedNetworkImage(imageUrl: proxyUrl, ...)` menggunakan `placeholder` dan `errorWidget` sesuai desain
  - Hapus `loadingBuilder` dari `Image.network` (digantikan oleh `placeholder` di `CachedNetworkImage`)
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [ ] 1.1 Tulis unit test untuk `DriveImage` menggunakan `CachedNetworkImage`
    - Verifikasi widget tree mengandung `CachedNetworkImage` (bukan `Image.network`)
    - Verifikasi `_placeholder()` muncul saat `imageUrl == null`
    - _Requirements: 1.3, 1.4_

- [-] 2. Rename sidebar "Kegiatan" → "Proyek" dan hapus item "Laporan"
  - Di `lib/shared/widgets/admin_scaffold.dart`, ubah `label: 'Kegiatan'` → `label: 'Proyek'` pada `_NavItem` yang mengarah ke `/admin/kegiatan`
  - Hapus `_NavItem` untuk route `/admin/laporan` dari daftar nav items
  - Pastikan urutan nav items setelah perubahan: Dashboard, Pegawai, Proyek, Dokumentasi, Rekap Upload, Import Data
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

  - [ ] 2.1 Tulis unit test untuk `_AdminSidebar`
    - Verifikasi teks "Proyek" ada di widget tree
    - Verifikasi teks "Kegiatan" tidak ada sebagai label nav item
    - Verifikasi teks "Laporan" tidak ada sebagai label nav item
    - _Requirements: 2.1, 2.3, 2.4_

  - [ ] 2.2 Tulis property test untuk active state sidebar (P1)
    - **Property 1: Sidebar active state mengikuti route**
    - Untuk semua route string yang dimulai dengan `/admin/kegiatan`, item "Proyek" harus `isActive == true` dan semua item lain `isActive == false`
    - **Validates: Requirements 2.5**

- [-] 3. Perbarui `DashboardStatsModel` dan `dashboardStats` provider
  - Di `lib/features/dashboard/domain/dashboard_stats_model.dart`, rename field `kegiatanAktif` → `jumlahProyek` dan `totalLaporan` → `totalDokumentasi`
  - Di `lib/features/dashboard/presentation/dashboard_provider.dart`, ubah query kedua dari `kegiatan` dengan filter `deadline >= today` menjadi `kegiatan` tanpa filter (COUNT semua baris)
  - Ubah query ketiga dari tabel `laporan` menjadi tabel `dokumentasi`
  - Hapus `recentLaporanProvider` (stream laporan terbaru) karena tidak lagi digunakan di dashboard
  - Update nama variabel lokal di provider agar konsisten dengan field baru
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

  - [ ] 3.1 Tulis unit test untuk `DashboardStatsModel`
    - Verifikasi field `jumlahProyek` dan `totalDokumentasi` ada dan dapat diinstansiasi
    - _Requirements: 3.1, 3.3_

- [-] 4. Perbarui `AdminDashboardScreen` — label kartu statistik dan hapus bagian Laporan Terbaru
  - Di `lib/features/dashboard/presentation/admin_dashboard_screen.dart`, ubah `StatCard` "Kegiatan Aktif" → "Jumlah Proyek" dengan `stats.jumlahProyek`, icon `Icons.folder_outlined`, `onTap` ke `/admin/kegiatan`
  - Ubah `StatCard` "Total Laporan" → "Total Dokumentasi" dengan `stats.totalDokumentasi`, icon `Icons.photo_library_outlined`, `onTap` ke `/admin/dokumentasi`
  - Hapus seluruh bagian "Laporan Terbaru" (Row header + `recentAsync.when(...)`) dari body screen
  - Hapus import `LaporanModel` dan `recentLaporanProvider` yang tidak lagi digunakan
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ] 4.1 Tulis unit test untuk `AdminDashboardScreen`
    - Verifikasi teks "Jumlah Proyek" ada di widget tree
    - Verifikasi teks "Total Dokumentasi" ada di widget tree
    - Verifikasi teks "Kegiatan Aktif" tidak ada
    - Verifikasi teks "Total Laporan" tidak ada
    - Verifikasi teks "Laporan Terbaru" tidak ada
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 5. Checkpoint — Pastikan semua tes lulus
  - Pastikan semua tes lulus, tanyakan kepada pengguna jika ada pertanyaan.

- [-] 6. Tambah `kegiatanListProvider` di `kegiatan_provider.dart`
  - Di `lib/features/kegiatan/presentation/kegiatan_provider.dart`, tambahkan provider baru `kegiatanList` bertipe `Future<List<KegiatanModel>>` yang memanggil `ref.read(kegiatanRepositoryProvider).getAll()`
  - Provider ini terpisah dari `KegiatanNotifier` agar pegawai tidak memicu state management admin
  - Jalankan `dart run build_runner build --delete-conflicting-outputs` untuk generate kode Riverpod
  - _Requirements: 4.1, 4.3, 4.7_

  - [ ] 6.1 Tulis property test untuk dropdown menampilkan semua proyek (P2)
    - **Property 2: Dropdown menampilkan semua proyek tanpa filter**
    - Untuk semua `List<KegiatanModel>` valid (ukuran 0–50, berbagai judul, berbagai deadline), jumlah item di `DropdownButtonFormField` harus sama persis dengan panjang list
    - **Validates: Requirements 4.1, 4.3**

  - [ ] 6.2 Tulis property test untuk nilai dropdown sesuai judul proyek (P3)
    - **Property 3: Nilai dropdown sesuai judul proyek yang dipilih**
    - Untuk semua `KegiatanModel` valid dengan judul random, ketika item dipilih, nilai `_selectedProyek` harus sama persis dengan `kegiatan.judul`
    - **Validates: Requirements 4.2**

- [-] 7. Modifikasi `DokumentasiFormSheet` — ganti `TextFormField` proyek & link dengan dropdown
  - Di `lib/features/dokumentasi/presentation/dokumentasi_screen.dart`, hapus `TextEditingController _proyekController` dan `TextEditingController _linkController`
  - Tambahkan state `String? _selectedProyek`
  - Hapus `TextFormField` untuk "Proyek / Kegiatan" dan "Link (opsional)"
  - Tambahkan `DropdownButtonFormField<String>` yang watch `kegiatanListProvider` dengan loading state, error state, dan empty state sesuai desain
  - Tambahkan import `kegiatanListProvider` dari `kegiatan_provider.dart`
  - Perbarui `_handleSubmit()` untuk menggunakan `_selectedProyek` sebagai nilai `proyek` dan hapus parameter `link`
  - Perbarui `dispose()` untuk menghapus dispose `_proyekController` dan `_linkController`
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 5.1_

  - [ ] 7.1 Tulis property test untuk validasi form tanpa proyek (P4)
    - **Property 4: Validasi form menolak submit tanpa proyek**
    - Untuk semua state form valid (foto ada/tidak, catatan ada/tidak, tanggal valid) di mana `_selectedProyek == null`, `_handleSubmit()` harus mengembalikan false dan tidak memanggil repository
    - **Validates: Requirements 4.6**

  - [ ] 7.2 Tulis unit test untuk `DokumentasiFormSheet`
    - Verifikasi field "Link (opsional)" tidak ada di widget tree
    - Verifikasi `DropdownButtonFormField` ada di widget tree
    - Verifikasi validator menampilkan "Wajib pilih proyek" saat submit tanpa memilih proyek
    - _Requirements: 4.6, 5.1_

- [x] 8. Modifikasi `DokumentasiNotifier.tambah()` — hapus parameter `link`
  - Di `lib/features/dokumentasi/presentation/dokumentasi_provider.dart`, hapus parameter `String? link` dari signature method `tambah()`
  - Hapus penerusan `link: link` ke `dokumentasiRepositoryProvider.create()`
  - _Requirements: 5.1, 5.2_

- [x] 9. Modifikasi `DokumentasiRepositoryImpl.create()` — auto-save Drive URL ke kolom `link`
  - Di `lib/features/dokumentasi/data/dokumentasi_repository_impl.dart`, hapus parameter `String? link` dari signature method `create()`
  - Setelah `_uploadToGoogleDrive()` berhasil dan mengembalikan `imageUrl`, set `'link': imageUrl` (bukan dari parameter)
  - Jika tidak ada gambar yang diupload (`imageUrl == null`), set `'link': null`
  - Perbarui interface `DokumentasiRepository` di `dokumentasi_repository.dart` untuk menghapus parameter `link` dari `create()`
  - _Requirements: 5.2_

- [-] 10. Modifikasi `DokCard` — ganti teks link dengan tombol "Copy Link"
  - Di `lib/features/dokumentasi/presentation/dokumentasi_screen.dart`, tambahkan import `package:flutter/services.dart`
  - Hapus import `url_launcher` jika tidak digunakan di tempat lain dalam file
  - Di widget `DokCard`, ganti blok `GestureDetector` yang memanggil `launchUrl` dengan `GestureDetector` yang memanggil `Clipboard.setData(ClipboardData(text: doc.link!))`
  - Setelah copy berhasil, tampilkan `SnackBar` dengan teks "Link berhasil disalin!" dan durasi 2 detik
  - Pastikan kondisi `if (doc.link != null)` tetap ada agar tombol hanya muncul saat link tersedia
  - _Requirements: 5.3, 5.4, 5.5, 5.6_

  - [ ] 10.1 Tulis property test untuk Copy Link (P5)
    - **Property 5: Copy Link muncul dan berfungsi untuk semua dokumentasi dengan link**
    - Untuk semua `DokumentasiModel` dengan `link != null` (berbagai URL, berbagai panjang string), `DokCard` harus menampilkan tombol "Copy Link" dan menekan tombol harus menyalin `doc.link` ke clipboard
    - **Validates: Requirements 5.3, 5.4**

  - [ ] 10.2 Tulis unit test untuk `DokCard`
    - Verifikasi tombol "Copy Link" muncul saat `doc.link != null`
    - Verifikasi tombol "Copy Link" tidak muncul saat `doc.link == null`
    - Verifikasi `SnackBar` "Link berhasil disalin!" muncul setelah tombol ditekan
    - _Requirements: 5.3, 5.5, 5.6_

- [ ] 11. Checkpoint — Pastikan semua tes lulus
  - Pastikan semua tes lulus, tanyakan kepada pengguna jika ada pertanyaan.

- [x] 12. Integrasi Logo BPS — aset, sidebar header, dan launcher icon
  - Copy file `scrap_kippapp/Logo-BPS.png` ke `pantau_pegawai_v2/assets/images/Logo-BPS.png`
  - Di `lib/shared/widgets/admin_scaffold.dart`, ganti `Icon(Icons.people_alt_rounded, color: Colors.white, size: 36)` dengan `Image.asset('assets/images/Logo-BPS.png', width: 48, height: 48)`
  - Di `pubspec.yaml`, tambahkan `flutter_launcher_icons: ^0.14.1` ke `dev_dependencies`
  - Di `pubspec.yaml`, tambahkan konfigurasi `flutter_launcher_icons` (android, ios, image_path, min_sdk_android, adaptive_icon_background, adaptive_icon_foreground) sesuai desain
  - Jalankan `dart run flutter_launcher_icons` untuk generate ikon launcher Android dan iOS
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7_

  - [ ] 12.1 Tulis unit test untuk Logo BPS di sidebar
    - Verifikasi `Image.asset` dengan path `assets/images/Logo-BPS.png` ada di header sidebar
    - Verifikasi `Icon(Icons.people_alt_rounded)` tidak ada di header sidebar
    - _Requirements: 6.3_

- [ ] 13. Final checkpoint — Pastikan semua tes lulus
  - Pastikan semua tes lulus, tanyakan kepada pengguna jika ada pertanyaan.

## Notes

- Task bertanda `*` bersifat opsional dan dapat dilewati untuk MVP yang lebih cepat
- Setiap task mereferensikan requirements spesifik untuk traceability
- Task 3 dan 4 harus dikerjakan bersamaan karena `DashboardStatsModel` digunakan di `AdminDashboardScreen`
- Task 8 dan 9 harus dikerjakan bersamaan karena signature `tambah()` dan `create()` harus konsisten
- Setelah Task 6, jalankan `dart run build_runner build --delete-conflicting-outputs` untuk generate kode Riverpod
- Setelah Task 12, jalankan `dart run flutter_launcher_icons` untuk generate ikon launcher
- Property tests menggunakan package `test` dengan generator manual (minimum 100 iterasi per property)
- Tag format property test: `// Feature: app-enhancement-proyek-cache, Property {N}: {property_text}`
