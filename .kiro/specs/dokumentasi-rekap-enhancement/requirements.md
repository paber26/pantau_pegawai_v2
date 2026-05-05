# Requirements Document

## Introduction

Fitur **dokumentasi-rekap-enhancement** adalah serangkaian peningkatan pada aplikasi Flutter PantauPegawai yang mencakup empat area utama:

1. **Halaman Dokumentasi (pegawai)** — Mengubah tampilan agar semua pegawai dapat melihat dokumentasi seluruh rekan kerja, bukan hanya milik sendiri, dengan filter per pegawai, proyek, dan tanggal.
2. **Halaman Riwayat (pegawai)** — Memastikan halaman riwayat hanya menampilkan dokumentasi milik user yang sedang login.
3. **Import Proyek Massal (admin)** — Menambahkan fitur bulk import 65 proyek/kegiatan ke halaman admin Kegiatan, bersifat idempotent.
4. **Halaman Rekap Upload (admin)** — Menambahkan menu dan halaman baru di area admin yang menampilkan rekapitulasi jumlah upload dokumentasi per pegawai, dengan filter bulan/tahun dan breakdown per bulan.

Aplikasi menggunakan Flutter + Riverpod + GoRouter dengan Supabase sebagai backend. Tabel utama yang terlibat: `dokumentasi`, `users`, dan `kegiatan`.

---

## Glossary

- **DokumentasiScreen**: Halaman di route `/pegawai/dokumentasi` yang menampilkan dokumentasi harian semua pegawai.
- **RiwayatDokumentasiScreen**: Halaman di route `/pegawai/riwayat` yang menampilkan riwayat dokumentasi milik user yang sedang login.
- **KegiatanListScreen**: Halaman di route `/admin/kegiatan` yang menampilkan daftar kegiatan/proyek untuk admin.
- **RekapUploadScreen**: Halaman baru di route `/admin/rekap-upload` yang menampilkan rekapitulasi upload dokumentasi per pegawai.
- **AdminScaffold**: Widget scaffold yang membungkus semua halaman admin, termasuk sidebar navigasi.
- **Pegawai**: User dengan role `pegawai` yang menggunakan aplikasi untuk mencatat dokumentasi harian.
- **Admin**: User dengan role `admin` yang mengelola data kegiatan, pegawai, dan melihat rekap.
- **Bulk Import**: Proses memasukkan banyak data sekaligus dalam satu operasi.
- **Idempotent**: Operasi yang menghasilkan hasil sama meskipun dijalankan berkali-kali; data yang sudah ada tidak akan diduplikasi.
- **Rekap Upload**: Ringkasan statistik jumlah dokumentasi yang diunggah oleh setiap pegawai dalam periode tertentu.
- **DokumentasiRepository**: Abstract class yang mendefinisikan kontrak akses data dokumentasi ke Supabase.
- **KegiatanRepository**: Abstract class yang mendefinisikan kontrak akses data kegiatan ke Supabase.
- **adminDokumentasiNotifierProvider**: Riverpod provider yang menyediakan semua data dokumentasi untuk tampilan admin/semua-pegawai.
- **myDokumentasiNotifierProvider**: Riverpod provider yang menyediakan data dokumentasi milik user yang sedang login.

---

## Requirements

### Requirement 1: Halaman Dokumentasi Menampilkan Semua Pegawai

**User Story:** Sebagai pegawai, saya ingin melihat dokumentasi harian semua rekan kerja di halaman Dokumentasi, sehingga saya dapat memantau aktivitas tim secara keseluruhan.

#### Acceptance Criteria

1. WHEN pengguna membuka halaman `/pegawai/dokumentasi`, THE DokumentasiScreen SHALL menampilkan dokumentasi dari semua pegawai, bukan hanya milik pengguna yang sedang login.
2. THE DokumentasiScreen SHALL menampilkan nama pegawai pemilik dokumentasi pada setiap card dokumentasi.
3. WHEN pengguna membuka halaman `/pegawai/dokumentasi`, THE DokumentasiScreen SHALL menggunakan `adminDokumentasiNotifierProvider` sebagai sumber data.
4. THE DokumentasiScreen SHALL menyediakan tombol filter yang memungkinkan pengguna memfilter dokumentasi berdasarkan nama pegawai.
5. THE DokumentasiScreen SHALL menyediakan tombol filter yang memungkinkan pengguna memfilter dokumentasi berdasarkan nama proyek/kegiatan.
6. THE DokumentasiScreen SHALL menyediakan tombol filter yang memungkinkan pengguna memfilter dokumentasi berdasarkan rentang tanggal (dari tanggal - sampai tanggal).
7. WHEN pengguna menerapkan filter pegawai, THE DokumentasiScreen SHALL hanya menampilkan dokumentasi milik pegawai yang dipilih.
8. WHEN pengguna menerapkan filter proyek, THE DokumentasiScreen SHALL hanya menampilkan dokumentasi yang nama proyeknya mengandung teks yang dimasukkan.
9. WHEN pengguna menerapkan filter tanggal, THE DokumentasiScreen SHALL hanya menampilkan dokumentasi dalam rentang tanggal yang dipilih.
10. WHEN pengguna menekan tombol reset filter, THE DokumentasiScreen SHALL menampilkan kembali semua dokumentasi tanpa filter.
11. THE DokumentasiScreen SHALL tetap menampilkan tombol tambah dokumentasi (FAB) sehingga pengguna dapat menambah dokumentasi milik sendiri.

---

### Requirement 2: Halaman Riwayat Hanya Menampilkan Data Milik Sendiri

**User Story:** Sebagai pegawai, saya ingin melihat riwayat dokumentasi saya sendiri di halaman Riwayat, sehingga saya dapat memantau dan mengelola catatan aktivitas pribadi saya.

#### Acceptance Criteria

1. WHEN pengguna membuka halaman `/pegawai/riwayat`, THE RiwayatDokumentasiScreen SHALL hanya menampilkan dokumentasi yang `user_id`-nya sama dengan ID pengguna yang sedang login.
2. THE RiwayatDokumentasiScreen SHALL menggunakan `myDokumentasiNotifierProvider` sebagai sumber data.
3. WHEN pengguna yang sedang login belum memiliki dokumentasi, THE RiwayatDokumentasiScreen SHALL menampilkan pesan kosong yang menyebutkan nama pengguna.
4. THE RiwayatDokumentasiScreen SHALL menampilkan dokumentasi dikelompokkan berdasarkan tanggal kegiatan, diurutkan dari terbaru ke terlama.
5. WHEN pengguna menekan tombol refresh, THE RiwayatDokumentasiScreen SHALL memuat ulang data dokumentasi milik pengguna yang sedang login.

---

### Requirement 3: Import Proyek Massal di Halaman Admin Kegiatan

**User Story:** Sebagai admin, saya ingin mengimpor daftar 65 proyek sekaligus ke database, sehingga saya tidak perlu memasukkan satu per satu secara manual.

#### Acceptance Criteria

1. THE KegiatanListScreen SHALL menampilkan tombol "Import Proyek" yang hanya terlihat oleh pengguna dengan role admin.
2. WHEN admin menekan tombol "Import Proyek", THE KegiatanListScreen SHALL menampilkan dialog konfirmasi sebelum memulai proses import.
3. WHEN admin mengkonfirmasi import, THE KegiatanRepository SHALL memasukkan 65 proyek yang telah ditentukan ke tabel `kegiatan` dalam satu operasi bulk insert.
4. WHEN proses import dijalankan, THE KegiatanRepository SHALL menetapkan deadline default setiap proyek ke tanggal 31 Desember 2026.
5. WHEN proyek dengan judul yang sama sudah ada di database, THE KegiatanRepository SHALL melewati proyek tersebut dan tidak membuat duplikat (idempotent).
6. WHEN proses import selesai, THE KegiatanListScreen SHALL menampilkan notifikasi yang menyebutkan jumlah proyek yang berhasil diimpor dan jumlah yang dilewati karena sudah ada.
7. IF terjadi kesalahan selama proses import, THEN THE KegiatanListScreen SHALL menampilkan pesan error yang deskriptif dan tidak mengubah data yang sudah ada.
8. WHEN proses import berhasil, THE KegiatanListScreen SHALL memuat ulang daftar kegiatan secara otomatis.

---

### Requirement 4: Halaman Rekap Upload Admin

**User Story:** Sebagai admin, saya ingin melihat rekapitulasi jumlah upload dokumentasi setiap pegawai, sehingga saya dapat memantau keaktifan pegawai dalam mencatat kegiatan harian.

#### Acceptance Criteria

1. THE AdminScaffold SHALL menampilkan menu "Rekap Upload" di sidebar navigasi admin dengan ikon yang sesuai.
2. WHEN admin menekan menu "Rekap Upload", THE AdminScaffold SHALL menavigasi ke route `/admin/rekap-upload`.
3. THE RekapUploadScreen SHALL menampilkan daftar semua pegawai beserta total jumlah dokumentasi yang telah diunggah.
4. THE RekapUploadScreen SHALL menampilkan breakdown jumlah upload per bulan (Januari hingga Desember) untuk setiap pegawai.
5. THE RekapUploadScreen SHALL menyediakan filter berdasarkan tahun sehingga admin dapat melihat rekap untuk tahun yang berbeda.
6. WHEN admin memilih tahun tertentu, THE RekapUploadScreen SHALL memperbarui tampilan untuk menampilkan data rekap tahun yang dipilih.
7. THE RekapUploadScreen SHALL menampilkan total keseluruhan upload dari semua pegawai sebagai ringkasan di bagian atas halaman.
8. THE RekapUploadScreen SHALL mengurutkan daftar pegawai berdasarkan total upload dari terbanyak ke tersedikit secara default.
9. WHEN data rekap sedang dimuat, THE RekapUploadScreen SHALL menampilkan indikator loading.
10. IF tidak ada data dokumentasi untuk periode yang dipilih, THEN THE RekapUploadScreen SHALL menampilkan pesan informatif bahwa belum ada data untuk periode tersebut.
11. WHEN admin menekan tombol refresh, THE RekapUploadScreen SHALL memuat ulang data rekap dari Supabase.
12. THE RekapUploadScreen SHALL menampilkan nama pegawai, jabatan, dan unit kerja pada setiap baris rekap.
