# Tahap 8 — Fitur Admin Dashboard

## 8.1 Navigasi Admin

Admin menggunakan **sidebar navigation** yang responsif:

- Layar lebar (≥800px): sidebar permanen di kiri
- Layar sempit: sidebar sebagai Drawer (hamburger menu)

Menu sidebar:

- Dashboard
- Pegawai
- Kegiatan
- Laporan
- Dokumentasi
- Rekap Upload
- Import Data
- Keluar

## 8.2 Dashboard Statistik

Menampilkan 4 stat card:
| Statistik | Sumber Data |
|-----------|-------------|
| Total Pegawai | `COUNT users WHERE role='pegawai'` |
| Kegiatan Aktif | `COUNT kegiatan WHERE deadline >= today` |
| Total Laporan | `COUNT laporan` |
| Belum Upload Hari Ini | Pegawai yang belum upload laporan hari ini |

Di bawah stat card: **Laporan Terbaru** menggunakan Supabase Realtime stream (update otomatis saat ada laporan baru).

## 8.3 CRUD Kegiatan

| Operasi | Keterangan                                     |
| ------- | ---------------------------------------------- |
| Tambah  | Form: judul, deskripsi, deadline (date picker) |
| Edit    | Form yang sama, pre-filled                     |
| Hapus   | Konfirmasi dialog                              |
| Assign  | Halaman checklist pegawai                      |

## 8.4 Assign Kegiatan ke Pegawai

Halaman `/admin/kegiatan/:id/assign` menampilkan daftar semua pegawai dengan checkbox.

- Centang = assign pegawai ke kegiatan
- Uncentang = unassign

Menggunakan tabel `penugasan` dengan constraint `UNIQUE(user_id, kegiatan_id)`.

## 8.5 Lihat Laporan

Filter yang tersedia:

- Rentang tanggal (dari - sampai)
- Pegawai tertentu
- Kegiatan tertentu

Detail laporan menampilkan:

- Foto fullscreen (InteractiveViewer untuk pinch-to-zoom)
- Info pegawai, kegiatan, waktu upload
- Deskripsi
- Tombol "Buka di Google Drive"

## 8.6 Lihat Dokumentasi

Menu **Dokumentasi** di sidebar admin menampilkan semua dokumentasi harian dari semua pegawai, dengan filter tanggal.

## 8.7 Import Data Spreadsheet

Menu **Import Data** di sidebar admin memungkinkan admin mengimpor data historis dari Google Spreadsheet (AppSheet lama) ke Supabase.

Wizard 5 langkah:

1. **Konfigurasi** — masukkan URL atau ID Google Spreadsheet
2. **Pratinjau** — pilih sheet dan lihat sampel data
3. **Pemetaan Kolom** — hubungkan kolom spreadsheet ke kolom tabel Supabase
4. **Validasi** — sistem memeriksa format data sebelum impor
5. **Hasil** — laporan berhasil/gagal per baris

Untuk migrasi data sekali jalan, gunakan script:

```bash
SUPABASE_SERVICE_ROLE_KEY=xxx node scripts/migrate-from-sheets.js
```

Script ini membaca sheet `DOKUMENTASI HARIAN` dari spreadsheet dan menginsert langsung ke tabel `dokumentasi`. URL foto Google Drive disimpan as-is ke kolom `image_url` tanpa perlu upload ulang.

## 8.8 Realtime Update

Dashboard menggunakan `Supabase.stream()` untuk laporan terbaru:

```dart
@riverpod
Stream<List<LaporanModel>> recentLaporan(Ref ref) {
  return Supabase.instance.client
      .from('laporan')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(10)
      .map((data) => data.map((e) => LaporanModel.fromMap(e)).toList());
}
```

Setiap kali ada laporan baru, list otomatis terupdate tanpa perlu refresh manual.
