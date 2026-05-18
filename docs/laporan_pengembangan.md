# Laporan Pengembangan Sistem Pantau Pegawai v2

## 1. Latar Belakang
Sistem Pantau Pegawai sebelumnya dikembangkan menggunakan AppSheet. Untuk meningkatkan fleksibilitas pengembangan dan memperluas dukungan platform secara mandiri, sistem ini dikembangkan ulang menggunakan framework yang lebih modern dan skalabel.

## 2. Pemilihan Teknologi
Pemilihan teknologi (stack) untuk pengembangan ulang didasarkan pada pertimbangan efisiensi, jangkauan platform, dan optimalisasi biaya:
- **Flutter**: Dipilih karena kemampuannya untuk melakukan *build* lintas platform (multi-device) dari satu basis kode (single codebase). Ini memungkinkan aplikasi berjalan dengan mulus di perangkat Android, iOS, dan Web browser.
- **Supabase**: Berperan sebagai layanan backend (Backend-as-a-Service). Supabase menyediakan database relasional (PostgreSQL) dan sistem autentikasi secara gratis yang sangat andal dan mudah diintegrasikan dengan Flutter.
- **Google Drive**: Dimanfaatkan sebagai solusi penyimpanan (*storage*) gratis untuk menyimpan file dokumentasi pekerjaan, menggantikan storage internal/berbayar untuk menekan biaya operasional.

## 3. Tahapan Pengembangan

Tahapan pengembangan sistem baru ini dibagi menjadi beberapa fase utama:

### 3.1. Analisis Kebutuhan Sistem
Pada tahap ini, dilakukan evaluasi mendalam terhadap alur kerja sistem lama di AppSheet untuk mengidentifikasi fungsionalitas yang wajib dipertahankan serta area yang membutuhkan peningkatan. Kebutuhan sistem baru mencakup pengalaman pengguna yang lebih responsif, dukungan penggunaan di berbagai jenis perangkat, serta integrasi penyimpanan dokumen terpusat tanpa batasan kuota yang ketat.

### 3.2. Perancangan Database dan Workflow Sistem
Struktur database dirancang ulang menggunakan PostgreSQL di dalam ekosistem Supabase. Relasi antar entitas (tabel pengguna, tabel aktivitas, log pekerjaan) disusun sedemikian rupa untuk memastikan *query* berjalan efisien dan *data integrity* tetap terjaga. Workflow aplikasi juga dipetakan ulang secara komprehensif, mulai dari alur autentikasi pengguna, manajemen *state* saat input data, hingga mekanisme sinkronisasi data dengan backend.

### 3.3. Pembuatan Antarmuka Aplikasi
Antarmuka pengguna (UI) dibangun menggunakan Flutter dengan pendekatan komponen yang modular (seperti pada modul presentasi autentikasi). Desain UI menitikberatkan pada prinsip *responsive design* sehingga tata letak secara otomatis menyesuaikan ukuran layar, baik itu ketika dibuka melalui *smartphone* (Android/iOS) maupun *desktop* (Web).

### 3.4. Pengembangan Fitur Utama
Pada tahap ini, dilakukan implementasi logika bisnis dan integrasi berbagai fitur utama aplikasi, antara lain:
* **Input aktivitas harian pegawai**: Formulir dinamis dan responsif bagi pegawai untuk melaporkan detail kegiatan sehari-hari mereka.
* **Monitoring progres pekerjaan**: Antarmuka bagi pengguna untuk memantau secara aktual (real-time) status pekerjaan dan proyek yang sedang berlangsung.
* **Dashboard monitoring untuk pimpinan**: Halaman khusus pimpinan yang menyajikan visualisasi data, metrik, dan ringkasan aktivitas guna mempermudah proses pengambilan keputusan.
* **Sistem laporan aktivitas**: Fitur untuk mengekspor atau mem-filter rekapan aktivitas harian dalam format yang terstruktur.
* **Upload dokumentasi pekerjaan**: Integrasi ke API Google Drive untuk memungkinkan pengguna langsung mengunggah foto maupun dokumen bukti penyelesaian tugas dari dalam aplikasi.
* **Manajemen akun dan hak akses pengguna**: Implementasi *Role-Based Access Control* (RBAC) menggunakan Supabase Auth guna mengatur izin (permission) berdasarkan jabatan, seperti hak akses antara pegawai staf dan pimpinan.

### 3.5. Pengujian Sistem
Tahap akhir sebelum rilis adalah pengujian sistem yang komprehensif (*testing*). Pengujian mencakup uji fungsi (fungsional) pada masing-masing fitur utama untuk memastikan tidak ada *bug*, uji responsivitas antarmuka di berbagai ukuran perangkat, serta uji integrasi (memastikan komunikasi antara Flutter, Supabase, dan Google Drive API berjalan lancar tanpa kendala token atau hak akses).
