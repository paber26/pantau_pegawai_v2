# Tahap 6 — Fitur Manajemen Pegawai

## 6.1 Fitur yang Tersedia

| Fitur                 | Status                  |
| --------------------- | ----------------------- |
| Lihat daftar pegawai  | ✅                      |
| Tambah pegawai baru   | ✅ via Edge Function    |
| Edit data pegawai     | ✅ langsung ke Supabase |
| Hapus pegawai         | ✅ via Edge Function    |
| Ubah password pegawai | ✅ via Edge Function    |

## 6.2 Mengapa Butuh Edge Function?

Operasi `auth.admin.createUser()`, `auth.admin.deleteUser()`, dan `auth.admin.updateUserById()` membutuhkan **service role key** yang tidak boleh ada di client Flutter (keamanan).

Solusi: semua operasi admin auth dilakukan via Edge Function yang menyimpan service role key sebagai secret.

## 6.3 Alur Tambah Pegawai

```
Admin isi form (nama, email, password, jabatan, unit_kerja, role)
    ↓
Flutter memanggil Edge Function admin-create-user
    ↓
Edge Function:
  1. Verifikasi admin JWT
  2. createUser() di Supabase Auth
  3. Trigger handle_new_user otomatis insert ke tabel users
  4. Tunggu 500ms
  5. UPDATE tabel users dengan data lengkap
    ↓
Return profil pegawai baru
    ↓
Flutter refresh daftar pegawai
```

## 6.4 Ubah Password

Tombol "Ubah Password" ada di halaman Edit Pegawai (icon kunci di AppBar dan tombol kuning di bawah form).

Dialog memiliki:

- Field password baru (min 6 karakter)
- Field konfirmasi password
- Toggle show/hide password
- Validasi kedua field harus cocok

## 6.5 Error Handling

Semua method di provider mengembalikan `String?` (null = sukses, string = pesan error):

```dart
final errorMsg = await ref.read(pegawaiNotifierProvider.notifier).create(...);
if (errorMsg != null) {
  // tampilkan error
} else {
  // sukses
}
```

## 6.6 Masalah yang Ditemui

### Conflict method `update` dengan AsyncNotifierBase

**Masalah:** Riverpod `AsyncNotifier` sudah punya method `update()` bawaan, sehingga method kita bentrok.

**Solusi:** Rename method menjadi `updatePegawai()` dan `updateKegiatan()`.

### Duplicate key saat tambah pegawai

**Masalah:** Trigger `handle_new_user` sudah insert ke tabel `users`, lalu Edge Function mencoba insert lagi → error `duplicate key value violates unique constraint "users_pkey"`.

**Solusi:** Ganti `INSERT` menjadi `UPDATE` di Edge Function, dengan delay 500ms untuk memastikan trigger sudah selesai.
