# Tahap 7 — Fitur Dokumentasi Harian

## 7.1 Konsep

Berbeda dari sistem laporan berbasis penugasan, **Dokumentasi Harian** memungkinkan pegawai mengupload foto kegiatan kapan saja tanpa perlu di-assign terlebih dahulu oleh admin.

Terinspirasi dari aplikasi AppSheet sebelumnya (https://s.bps.go.id/pantau_pegawai).

## 7.2 Field Dokumentasi

| Field            | Tipe | Wajib | Keterangan                         |
| ---------------- | ---- | ----- | ---------------------------------- |
| proyek           | TEXT | ✅    | Nama proyek/kegiatan (bebas input) |
| tanggal_kegiatan | DATE | ✅    | Default: hari ini                  |
| image_url        | TEXT | ❌    | URL foto di Google Drive           |
| catatan          | TEXT | ❌    | Deskripsi kegiatan                 |
| link             | TEXT | ❌    | Link referensi                     |

## 7.3 Halaman Dokumentasi (Tab 1)

Menampilkan **semua dokumentasi dari semua pegawai**, dikelompokkan per tanggal.

### Filter yang tersedia:

- **Pegawai** — dropdown pilih pegawai tertentu
- **Kegiatan/Proyek** — text search
- **Rentang tanggal** — dari tanggal & sampai tanggal

### Fitur tambahan:

- Pegawai hanya bisa hapus dokumentasi miliknya sendiri (icon ⋮ hanya muncul untuk pemilik)
- Tap foto untuk lihat fullscreen dengan pinch-to-zoom
- Tap link untuk buka di browser

## 7.4 Halaman Riwayat (Tab 2)

Menampilkan **hanya dokumentasi milik pegawai yang sedang login**, dikelompokkan per tanggal.

## 7.5 Form Tambah Dokumentasi

Muncul sebagai bottom sheet dari tombol FAB "Tambah".

Field:

1. Foto (opsional) — kamera atau galeri
2. Proyek/Kegiatan (wajib)
3. Tanggal Kegiatan (default hari ini, bisa diubah)
4. Catatan (opsional)
5. Link (opsional)

## 7.6 Tampilan List

Dokumentasi dikelompokkan per tanggal dengan label:

- **Hari Ini** (badge biru solid)
- **Kemarin**
- **d MMMM yyyy** (format Indonesia, contoh: 3 Mei 2026)

Setiap card menampilkan:

- Thumbnail foto (60×60)
- Nama pegawai (di halaman Dokumentasi)
- Nama proyek
- Catatan (2 baris)
- Waktu upload (HH:mm)
- Link (jika ada)

## 7.7 Upload Foto ke Google Drive

Foto diupload via Edge Function `upload-to-drive` dengan struktur folder:

```
/PantauPegawai/{nama_pegawai}/{yyyy-mm-dd}/foto_{timestamp}.jpg
```

Foto bersifat opsional — dokumentasi bisa disimpan tanpa foto.

## 7.8 Admin View

Admin bisa melihat semua dokumentasi dari menu **Dokumentasi** di sidebar admin, dengan filter tanggal.

## 7.9 Masalah yang Ditemui

### LocaleDataException

**Masalah:** `DateFormat('d MMMM yyyy', 'id_ID')` crash dengan error `Locale data has not been initialized`.

**Solusi:** Tambahkan di `main.dart` sebelum `runApp()`:

```dart
await initializeDateFormatting('id_ID', null);
```
