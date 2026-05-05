# Dokumen Requirements

## Pendahuluan

Fitur ini memungkinkan admin aplikasi **Pantau Pegawai** untuk mengimpor data historis dari Google Spreadsheet (yang sebelumnya digunakan sebagai database AppSheet) ke dalam database Supabase yang baru. Selain proses impor satu kali, fitur ini juga menyediakan tampilan pratinjau data spreadsheet sebelum diimpor, pemetaan kolom spreadsheet ke tabel Supabase, serta laporan hasil impor.

Fitur ini bersifat **admin-only** dan dirancang sebagai alat migrasi data satu arah: dari Google Spreadsheet ke Supabase. Setelah data berhasil diimpor, data tersebut menjadi bagian dari database Supabase dan dapat dikelola melalui fitur-fitur yang sudah ada.

> **Catatan Implementasi (Update):** Gambar/foto dari spreadsheet lama **tidak perlu diupload ulang** ke Google Drive baru. URL/link Drive yang sudah ada di kolom spreadsheet disimpan langsung ke field `image_url` di Supabase as-is. Kolom `image_url` pada tabel `laporan` dan `dokumentasi` bersifat opsional (tidak required) dalam konteks impor ini.

## Glosarium

- **Admin**: Pengguna dengan role `admin` dalam sistem Pantau Pegawai.
- **Spreadsheet**: Google Spreadsheet yang sebelumnya digunakan sebagai database AppSheet.
- **Sheet**: Lembar kerja (tab) di dalam Spreadsheet, masing-masing merepresentasikan satu entitas data (misalnya: Pegawai, Kegiatan, Laporan).
- **Google_Sheets_API**: Layanan Google Sheets API v4 yang digunakan untuk membaca data dari Spreadsheet secara publik.
- **Importer**: Komponen sistem yang bertanggung jawab mengambil, memvalidasi, dan menyimpan data dari Spreadsheet ke Supabase.
- **Supabase_Client**: Klien Supabase Flutter yang digunakan untuk berinteraksi dengan database PostgreSQL.
- **Pratinjau_Data**: Tampilan data mentah dari Spreadsheet sebelum proses impor dilakukan.
- **Pemetaan_Kolom**: Proses menghubungkan nama kolom di Spreadsheet dengan nama kolom di tabel Supabase.
- **Hasil_Impor**: Ringkasan proses impor yang mencakup jumlah baris berhasil, gagal, dan pesan error.
- **Spreadsheet_ID**: Identifikasi unik Google Spreadsheet yang diambil dari URL spreadsheet.
- **API_Key**: Kunci API Google yang digunakan untuk mengakses Google Sheets API tanpa autentikasi OAuth.
- **Edge_Function**: Supabase Edge Function berbasis Deno yang berjalan di server untuk menangani logika impor.

---

## Requirements

### Requirement 1: Konfigurasi Sumber Data Spreadsheet

**User Story:** Sebagai admin, saya ingin mengonfigurasi URL atau ID Google Spreadsheet yang akan diimpor, sehingga sistem dapat mengambil data dari sumber yang benar.

#### Acceptance Criteria

1. THE Importer SHALL menerima input berupa URL lengkap Google Spreadsheet atau Spreadsheet_ID secara langsung.
2. WHEN admin memasukkan URL Google Spreadsheet yang valid, THE Importer SHALL mengekstrak Spreadsheet_ID dari URL tersebut secara otomatis.
3. WHEN admin memasukkan Spreadsheet_ID yang valid, THE Importer SHALL menyimpan Spreadsheet_ID untuk digunakan pada langkah berikutnya.
4. IF admin memasukkan URL atau Spreadsheet_ID yang tidak valid, THEN THE Importer SHALL menampilkan pesan error yang menjelaskan format yang benar.
5. THE Importer SHALL mendukung format URL Google Spreadsheet standar: `https://docs.google.com/spreadsheets/d/{SPREADSHEET_ID}/edit`.

---

### Requirement 2: Pengambilan Daftar Sheet

**User Story:** Sebagai admin, saya ingin melihat daftar sheet yang tersedia di Spreadsheet, sehingga saya dapat memilih sheet mana yang akan diimpor.

#### Acceptance Criteria

1. WHEN Spreadsheet_ID valid telah dikonfigurasi, THE Google_Sheets_API SHALL mengembalikan daftar nama sheet yang tersedia dalam Spreadsheet.
2. THE Importer SHALL menampilkan daftar sheet kepada admin dalam bentuk pilihan yang dapat dipilih.
3. IF Google_Sheets_API tidak dapat diakses atau Spreadsheet tidak ditemukan, THEN THE Importer SHALL menampilkan pesan error yang menjelaskan penyebab kegagalan.
4. IF Spreadsheet bersifat privat dan tidak dapat diakses secara publik, THEN THE Importer SHALL menampilkan pesan error yang meminta admin untuk memastikan Spreadsheet dapat diakses oleh siapa saja yang memiliki tautan.
5. WHEN daftar sheet berhasil diambil, THE Importer SHALL menampilkan jumlah sheet yang tersedia.

---

### Requirement 3: Pratinjau Data Sheet

**User Story:** Sebagai admin, saya ingin melihat pratinjau data dari sheet yang dipilih sebelum melakukan impor, sehingga saya dapat memverifikasi data yang akan diimpor.

#### Acceptance Criteria

1. WHEN admin memilih sebuah sheet, THE Google_Sheets_API SHALL mengambil data dari sheet tersebut termasuk baris header dan maksimal 10 baris data pertama sebagai pratinjau.
2. THE Importer SHALL menampilkan data pratinjau dalam bentuk tabel dengan header kolom dari baris pertama sheet.
3. THE Importer SHALL menampilkan jumlah total baris data (tidak termasuk header) yang tersedia di sheet.
4. IF sheet yang dipilih kosong atau hanya berisi header tanpa data, THEN THE Importer SHALL menampilkan pesan informasi bahwa sheet tidak memiliki data untuk diimpor.
5. WHEN data pratinjau ditampilkan, THE Importer SHALL menampilkan nama-nama kolom yang terdeteksi dari baris pertama sheet.

---

### Requirement 4: Pemetaan Kolom ke Tabel Supabase

**User Story:** Sebagai admin, saya ingin memetakan kolom-kolom dari sheet ke kolom-kolom tabel Supabase yang sesuai, sehingga data dapat diimpor ke struktur database yang benar.

#### Acceptance Criteria

1. WHEN admin telah melihat pratinjau data, THE Importer SHALL menampilkan antarmuka pemetaan kolom yang menampilkan kolom sumber (dari sheet) dan kolom tujuan (dari tabel Supabase).
2. THE Importer SHALL menyediakan pilihan tabel Supabase tujuan yang tersedia: `users` (pegawai), `kegiatan`, `laporan`, dan `dokumentasi`.
3. WHEN admin memilih tabel tujuan, THE Importer SHALL menampilkan daftar kolom yang tersedia di tabel tersebut beserta tipe datanya.
4. THE Importer SHALL memungkinkan admin untuk memetakan setiap kolom sumber ke kolom tujuan yang sesuai melalui dropdown.
5. THE Importer SHALL memungkinkan admin untuk menandai kolom sumber tertentu sebagai "abaikan" jika kolom tersebut tidak perlu diimpor.
6. IF kolom yang diwajibkan (NOT NULL) di tabel tujuan tidak dipetakan, THEN THE Importer SHALL menampilkan peringatan sebelum proses impor dimulai.
7. THE Importer SHALL menyimpan konfigurasi pemetaan kolom yang telah dibuat admin untuk referensi selama sesi impor berlangsung.

---

### Requirement 5: Validasi Data Sebelum Impor

**User Story:** Sebagai admin, saya ingin sistem memvalidasi data sebelum diimpor, sehingga data yang masuk ke Supabase terjamin kualitasnya.

#### Acceptance Criteria

1. WHEN admin memulai proses validasi, THE Importer SHALL memeriksa setiap baris data berdasarkan pemetaan kolom yang telah dikonfigurasi.
2. THE Importer SHALL memvalidasi bahwa kolom bertipe tanggal berisi nilai yang dapat diparse menjadi format tanggal yang valid.
3. THE Importer SHALL memvalidasi bahwa kolom yang diwajibkan (NOT NULL) tidak berisi nilai kosong.
4. WHEN validasi selesai, THE Importer SHALL menampilkan ringkasan validasi yang mencakup jumlah baris valid dan jumlah baris dengan error.
5. IF terdapat baris dengan error validasi, THEN THE Importer SHALL menampilkan detail error per baris beserta nama kolom dan nilai yang bermasalah.
6. THE Importer SHALL memungkinkan admin untuk melanjutkan impor hanya untuk baris yang valid, dengan mengabaikan baris yang memiliki error.

---

### Requirement 6: Proses Impor Data ke Supabase

**User Story:** Sebagai admin, saya ingin mengimpor data yang telah divalidasi ke Supabase, sehingga data historis dari AppSheet tersedia di aplikasi baru.

#### Acceptance Criteria

1. WHEN admin mengonfirmasi untuk memulai impor, THE Importer SHALL mengirimkan data yang valid ke Edge_Function untuk diproses.
2. THE Edge_Function SHALL menerima data dalam format batch dan menyimpannya ke tabel Supabase yang sesuai menggunakan operasi `upsert`.
3. WHILE proses impor berlangsung, THE Importer SHALL menampilkan indikator progres yang menunjukkan persentase baris yang telah diproses.
4. THE Edge_Function SHALL memproses data dalam batch berukuran maksimal 100 baris per permintaan untuk menghindari timeout.
5. IF terjadi error pada saat menyimpan sebuah baris, THEN THE Edge_Function SHALL mencatat error tersebut dan melanjutkan pemrosesan baris berikutnya tanpa menghentikan seluruh proses impor.
6. WHEN proses impor selesai, THE Importer SHALL menampilkan Hasil_Impor yang mencakup jumlah baris berhasil diimpor, jumlah baris gagal, dan daftar error jika ada.

---

### Requirement 7: Laporan Hasil Impor

**User Story:** Sebagai admin, saya ingin melihat laporan hasil impor yang detail, sehingga saya dapat mengetahui status setiap baris data yang diproses.

#### Acceptance Criteria

1. WHEN proses impor selesai, THE Importer SHALL menampilkan halaman Hasil_Impor yang merangkum keseluruhan proses.
2. THE Importer SHALL menampilkan statistik impor yang mencakup: total baris diproses, jumlah berhasil, jumlah gagal, dan waktu yang dibutuhkan.
3. IF terdapat baris yang gagal diimpor, THEN THE Importer SHALL menampilkan daftar baris gagal beserta nomor baris, data asli, dan pesan error dari Supabase.
4. THE Importer SHALL memungkinkan admin untuk mengunduh laporan hasil impor dalam format teks atau menyalinnya ke clipboard.
5. WHEN admin menekan tombol "Selesai" pada halaman Hasil_Impor, THE Importer SHALL mengarahkan admin kembali ke halaman awal fitur impor.

---

### Requirement 8: Keamanan dan Otorisasi

**User Story:** Sebagai admin, saya ingin fitur impor hanya dapat diakses oleh pengguna dengan role admin, sehingga data tidak dapat dimanipulasi oleh pegawai biasa.

#### Acceptance Criteria

1. THE Importer SHALL hanya dapat diakses oleh pengguna yang telah terautentikasi dengan role `admin`.
2. WHEN pengguna dengan role `pegawai` mencoba mengakses halaman impor, THE Importer SHALL mengarahkan pengguna tersebut ke halaman yang sesuai dengan role-nya.
3. THE Edge_Function SHALL memverifikasi JWT token Supabase pada setiap permintaan dan menolak permintaan tanpa token yang valid.
4. THE Edge_Function SHALL memverifikasi bahwa pengguna yang membuat permintaan memiliki role `admin` sebelum memproses data impor.
5. IF permintaan ke Edge_Function tidak memiliki token yang valid atau pengguna bukan admin, THEN THE Edge_Function SHALL mengembalikan respons HTTP 403 Forbidden.

---

### Requirement 9: Penanganan Koneksi dan Error Jaringan

**User Story:** Sebagai admin, saya ingin sistem menangani error jaringan dengan baik, sehingga proses impor tidak gagal total karena masalah koneksi sementara.

#### Acceptance Criteria

1. IF koneksi ke Google_Sheets_API terputus saat mengambil data, THEN THE Importer SHALL menampilkan pesan error yang jelas dan menyediakan tombol untuk mencoba ulang.
2. IF koneksi ke Supabase terputus saat proses impor berlangsung, THEN THE Importer SHALL menghentikan proses impor dan menampilkan Hasil_Impor parsial yang mencakup baris yang sudah berhasil diproses.
3. THE Importer SHALL menerapkan timeout 30 detik untuk setiap permintaan ke Google_Sheets_API.
4. THE Edge_Function SHALL menerapkan timeout 60 detik untuk setiap batch pemrosesan data ke Supabase.
5. WHEN terjadi error jaringan yang dapat dipulihkan, THE Importer SHALL melakukan percobaan ulang otomatis sebanyak maksimal 3 kali dengan jeda 2 detik antar percobaan sebelum menampilkan pesan error kepada admin.
