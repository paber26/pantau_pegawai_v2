# Requirements Document

## Introduction

Fitur ini mencakup serangkaian peningkatan pada aplikasi Flutter `pantau_pegawai_v2` yang bertujuan untuk:

1. **Image Caching** — Gambar dokumentasi harian yang diambil dari Google Drive melalui Supabase image-proxy di-cache secara lokal di perangkat, sehingga tidak perlu diunduh ulang selama konten masih sama.
2. **Rename Kegiatan → Proyek** — Sidebar admin "Kegiatan" diganti menjadi "Proyek", dan seluruh terminologi "kegiatan" di sisi admin diganti menjadi "proyek" agar konsisten dengan domain bisnis.
3. **Pembaruan Dashboard Admin** — Statistik dashboard diperbarui: menampilkan jumlah proyek, mengganti label "Kegiatan Aktif" → "Jumlah Proyek", mengganti "Total Laporan" → jumlah dokumentasi yang masuk, dan menghapus sidebar "Laporan" yang belum digunakan.
4. **Dropdown Proyek di Halaman User** — Form dokumentasi harian menampilkan dropdown proyek yang bersumber dari data proyek yang sudah di-insert admin, menggantikan input teks bebas.
5. **Tombol Copy Link Drive** — Field input "Link" dihapus dari form dokumentasi; sebagai gantinya, pada kartu dokumentasi yang sudah tersimpan ditampilkan tombol "Copy Link" untuk menyalin URL Google Drive tempat gambar disimpan.
6. **Logo BPS** — Logo BPS dimasukkan ke aset aplikasi, ditampilkan di halaman admin, dan dijadikan ikon aplikasi (launcher icon) untuk Android dan iOS.

Aplikasi menggunakan Flutter + Supabase sebagai backend, dengan gambar disimpan di Google Drive dan diakses melalui Supabase Edge Function `image-proxy`.

---

## Glossary

- **App**: Aplikasi Flutter `pantau_pegawai_v2`.
- **Image_Cache**: Mekanisme penyimpanan gambar lokal di perangkat menggunakan package `cached_network_image`.
- **Drive_Image**: Widget Flutter (`drive_image.dart`) yang menampilkan gambar dari Google Drive melalui `image-proxy`.
- **Image_Proxy**: Supabase Edge Function yang menjadi perantara akses gambar dari Google Drive.
- **Proyek**: Entitas yang sebelumnya disebut "Kegiatan" di sisi admin; merepresentasikan proyek/kegiatan yang dapat ditugaskan ke pegawai.
- **Dokumentasi**: Entri harian yang dibuat pegawai, berisi foto, nama proyek, tanggal, dan catatan.
- **Admin**: Pengguna dengan role `admin` yang mengelola data proyek, pegawai, dan melihat dokumentasi.
- **Pegawai**: Pengguna dengan role `pegawai` yang membuat dokumentasi harian.
- **Dashboard**: Halaman ringkasan statistik yang ditampilkan kepada Admin setelah login.
- **Sidebar**: Panel navigasi di sisi kiri layar pada tampilan Admin.
- **Drive_URL**: URL atau ID file gambar yang tersimpan di Google Drive, dihasilkan oleh Edge Function `upload-to-drive`.
- **Launcher_Icon**: Ikon yang ditampilkan di layar utama perangkat Android/iOS saat aplikasi diinstal.
- **Logo_BPS**: File gambar logo Badan Pusat Statistik yang digunakan sebagai identitas visual aplikasi.
- **Copy_Link**: Tombol yang menyalin Drive_URL ke clipboard perangkat.
- **Dropdown_Proyek**: Komponen UI berupa daftar pilihan proyek yang bersumber dari tabel `kegiatan` di Supabase.

---

## Requirements

### Requirement 1: Image Caching untuk Dokumentasi Harian

**User Story:** Sebagai Pegawai atau Admin, saya ingin gambar dokumentasi harian yang sudah pernah diunduh tersimpan di perangkat, sehingga saya tidak perlu mengunduh ulang gambar yang sama dan penggunaan data internet berkurang.

#### Acceptance Criteria

1. WHEN Drive_Image menampilkan gambar melalui Image_Proxy, THE Image_Cache SHALL menyimpan gambar tersebut di storage lokal perangkat berdasarkan URL proxy sebagai cache key.
2. WHEN Drive_Image dimuat ulang dengan URL yang sama, THE Image_Cache SHALL menampilkan gambar dari cache lokal tanpa melakukan request jaringan baru ke Image_Proxy.
3. WHEN gambar sedang diunduh untuk pertama kali, THE Drive_Image SHALL menampilkan indikator loading (CircularProgressIndicator).
4. IF gambar gagal dimuat dari jaringan maupun cache, THEN THE Drive_Image SHALL menampilkan placeholder ikon gambar.
5. THE Image_Cache SHALL menggunakan package `cached_network_image` yang sudah terdaftar di `pubspec.yaml` sebagai mekanisme caching.
6. WHEN ukuran cache melebihi batas default package `cached_network_image`, THE Image_Cache SHALL menghapus entri cache terlama secara otomatis (LRU eviction).

---

### Requirement 2: Rename Sidebar "Kegiatan" menjadi "Proyek" di Admin

**User Story:** Sebagai Admin, saya ingin sidebar navigasi menampilkan label "Proyek" menggantikan "Kegiatan", sehingga terminologi yang digunakan konsisten dengan domain bisnis yang sebenarnya.

#### Acceptance Criteria

1. THE Sidebar SHALL menampilkan item navigasi dengan label "Proyek" pada posisi yang sebelumnya menampilkan "Kegiatan".
2. WHEN Admin menekan item "Proyek" di Sidebar, THE App SHALL menavigasi ke halaman daftar proyek (`/admin/kegiatan`).
3. THE Sidebar SHALL tidak lagi menampilkan item navigasi dengan label "Laporan".
4. THE Sidebar SHALL tetap menampilkan item navigasi: Dashboard, Pegawai, Proyek, Dokumentasi, Rekap Upload, dan Import Data.
5. WHEN Admin berada di halaman daftar proyek atau sub-halaman proyek, THE Sidebar SHALL menandai item "Proyek" sebagai aktif (highlighted).

---

### Requirement 3: Pembaruan Dashboard Admin

**User Story:** Sebagai Admin, saya ingin dashboard menampilkan statistik yang relevan — jumlah proyek dan jumlah dokumentasi yang masuk — sehingga saya mendapatkan gambaran akurat tentang aktivitas aplikasi.

#### Acceptance Criteria

1. THE Dashboard SHALL menampilkan kartu statistik dengan label "Jumlah Proyek" yang menunjukkan total jumlah baris di tabel `kegiatan`.
2. THE Dashboard SHALL tidak lagi menampilkan kartu statistik dengan label "Kegiatan Aktif".
3. THE Dashboard SHALL menampilkan kartu statistik dengan label "Total Dokumentasi" yang menunjukkan total jumlah baris di tabel `dokumentasi`.
4. THE Dashboard SHALL tidak lagi menampilkan kartu statistik dengan label "Total Laporan".
5. WHEN Admin menekan kartu "Jumlah Proyek", THE App SHALL menavigasi ke halaman `/admin/kegiatan`.
6. WHEN Admin menekan kartu "Total Dokumentasi", THE App SHALL menavigasi ke halaman `/admin/dokumentasi`.
7. THE Dashboard SHALL tetap menampilkan kartu "Total Pegawai" dan kartu "Belum Upload".
8. WHEN data statistik sedang dimuat, THE Dashboard SHALL menampilkan shimmer loading placeholder.
9. IF query statistik gagal, THEN THE Dashboard SHALL menampilkan pesan error yang dapat di-retry.

---

### Requirement 4: Dropdown Proyek di Form Dokumentasi Pegawai

**User Story:** Sebagai Pegawai, saya ingin memilih proyek dari daftar dropdown yang sudah disiapkan admin, sehingga nama proyek yang diinput konsisten dan tidak ada kesalahan pengetikan.

#### Acceptance Criteria

1. WHEN Pegawai membuka form tambah dokumentasi, THE Dropdown_Proyek SHALL menampilkan daftar proyek yang bersumber dari tabel `kegiatan` di Supabase.
2. WHEN Pegawai memilih satu proyek dari Dropdown_Proyek, THE App SHALL mengisi field proyek dengan nilai `judul` dari proyek yang dipilih.
3. THE Dropdown_Proyek SHALL menampilkan semua proyek yang tersedia tanpa filter status atau deadline.
4. IF daftar proyek kosong, THEN THE Dropdown_Proyek SHALL menampilkan teks "Belum ada proyek tersedia".
5. IF pengambilan daftar proyek gagal, THEN THE App SHALL menampilkan pesan error dan tetap memungkinkan Pegawai menutup form.
6. WHEN form dokumentasi disubmit, THE App SHALL memvalidasi bahwa Pegawai telah memilih proyek dari Dropdown_Proyek sebelum menyimpan data.
7. THE Dropdown_Proyek SHALL menampilkan indikator loading saat data proyek sedang diambil dari Supabase.

---

### Requirement 5: Tombol Copy Link Drive pada Kartu Dokumentasi

**User Story:** Sebagai Pegawai, saya ingin menyalin link Google Drive tempat gambar dokumentasi saya tersimpan dengan satu ketukan, sehingga saya dapat berbagi atau mengakses file tersebut dengan mudah.

#### Acceptance Criteria

1. THE DokumentasiFormSheet SHALL tidak menampilkan field input "Link (opsional)" kepada Pegawai.
2. WHEN Pegawai menyimpan dokumentasi dengan gambar, THE App SHALL menyimpan Drive_URL yang dihasilkan oleh Edge Function `upload-to-drive` ke kolom `link` di tabel `dokumentasi` secara otomatis.
3. WHEN kartu dokumentasi ditampilkan dan kolom `link` berisi Drive_URL, THE DokCard SHALL menampilkan tombol "Copy Link" menggantikan teks link yang dapat diklik.
4. WHEN Pegawai menekan tombol "Copy Link", THE App SHALL menyalin Drive_URL ke clipboard perangkat.
5. WHEN Drive_URL berhasil disalin ke clipboard, THE App SHALL menampilkan SnackBar konfirmasi dengan teks "Link berhasil disalin!".
6. WHEN kartu dokumentasi ditampilkan dan kolom `link` kosong atau null, THE DokCard SHALL tidak menampilkan tombol "Copy Link".

---

### Requirement 6: Integrasi Logo BPS

**User Story:** Sebagai Admin, saya ingin aplikasi menggunakan logo BPS sebagai identitas visual, sehingga aplikasi terlihat resmi dan sesuai dengan branding instansi.

#### Acceptance Criteria

1. THE App SHALL menyertakan file `Logo-BPS.png` di direktori aset `assets/images/` pada repository `pantau_pegawai_v2`.
2. THE App SHALL mendaftarkan `assets/images/Logo-BPS.png` di bagian `flutter.assets` pada `pubspec.yaml`.
3. WHEN halaman admin (Sidebar atau Dashboard) ditampilkan, THE App SHALL menampilkan Logo_BPS di bagian header Sidebar menggantikan ikon `Icons.people_alt_rounded`.
4. THE Launcher_Icon untuk platform Android SHALL menggunakan Logo_BPS sebagai ikon aplikasi yang ditampilkan di layar utama perangkat.
5. THE Launcher_Icon untuk platform iOS SHALL menggunakan Logo_BPS sebagai ikon aplikasi yang ditampilkan di layar utama perangkat.
6. WHERE platform adalah Android, THE App SHALL menyertakan varian ikon launcher dalam resolusi: mdpi, hdpi, xhdpi, xxhdpi, dan xxxhdpi.
7. WHERE platform adalah iOS, THE App SHALL menyertakan varian ikon launcher dalam ukuran yang dipersyaratkan oleh App Store (minimal 1024×1024 px untuk App Store Connect).
