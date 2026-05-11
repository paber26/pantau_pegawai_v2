# Tahap 4 — Supabase Edge Functions

Edge Functions adalah server-side code yang berjalan di Deno runtime. Digunakan untuk operasi yang membutuhkan service role key atau credentials sensitif.

## Daftar Edge Functions

| Function               | Path                                 | Kegunaan                            |
| ---------------------- | ------------------------------------ | ----------------------------------- |
| `admin-create-user`    | `/functions/v1/admin-create-user`    | Buat akun pegawai baru              |
| `admin-delete-user`    | `/functions/v1/admin-delete-user`    | Hapus akun pegawai                  |
| `admin-reset-password` | `/functions/v1/admin-reset-password` | Ubah password pegawai               |
| `upload-to-drive`      | `/functions/v1/upload-to-drive`      | Upload foto ke Google Drive         |
| `image-proxy`          | `/functions/v1/image-proxy`          | Proxy gambar dari Google Drive      |
| `import-from-sheets`   | `/functions/v1/import-from-sheets`   | Import data dari Google Spreadsheet |

## Cara Deploy (Via Browser)

1. Buka Supabase Dashboard → **Edge Functions**
2. Klik **Deploy a new function → Via Editor**
3. Isi nama function (sesuai tabel di atas)
4. Copy-paste kode dari folder `supabase/functions/`
5. Klik **Deploy**

## 4.1 admin-create-user

**File:** `supabase/functions/admin-create-user/index.ts`

**Alur:**

1. Verifikasi JWT caller → cek role = 'admin'
2. Buat auth user via `adminClient.auth.admin.createUser()`
3. Tunggu 500ms agar trigger `handle_new_user` selesai insert ke tabel `users`
4. Update profil dengan data lengkap (nama, jabatan, unit_kerja, role)

**Request:**

```json
POST /functions/v1/admin-create-user
Authorization: Bearer <jwt_token>

{
  "nama": "Budi Santoso",
  "email": "budi@instansi.go.id",
  "password": "password123",
  "jabatan": "Staf Statistik",
  "unit_kerja": "Seksi Produksi",
  "role": "pegawai"
}
```

**Response sukses:**

```json
{ "success": true, "user": { "id": "...", "nama": "Budi Santoso", ... } }
```

## 4.2 admin-delete-user

**File:** `supabase/functions/admin-delete-user/index.ts`

**Alur:**

1. Verifikasi JWT caller → cek role = 'admin'
2. Cegah admin hapus dirinya sendiri
3. Hapus via `adminClient.auth.admin.deleteUser(user_id)`
4. Cascade delete otomatis menghapus dari tabel `users`, `penugasan`, `laporan`, `dokumentasi`

**Request:**

```json
POST /functions/v1/admin-delete-user
Authorization: Bearer <jwt_token>

{ "user_id": "uuid-pegawai" }
```

## 4.3 admin-reset-password

**File:** `supabase/functions/admin-reset-password/index.ts`

**Alur:**

1. Verifikasi JWT caller → cek role = 'admin'
2. Validasi password minimal 6 karakter
3. Update via `adminClient.auth.admin.updateUserById(user_id, { password })`

**Request:**

```json
POST /functions/v1/admin-reset-password
Authorization: Bearer <jwt_token>

{ "user_id": "uuid-pegawai", "new_password": "password_baru" }
```

## 4.4 upload-to-drive

**File:** `supabase/functions/upload-to-drive/index.ts`

**Alur:**

1. Verifikasi JWT Supabase
2. Parse multipart form data (file + metadata)
3. Generate Google access token dari Service Account JWT
4. Buat struktur folder di Drive: `/PantauPegawai/{nama_pegawai}/{yyyy-mm-dd}/`
5. Upload file dengan multipart upload
6. Set permission: anyone with link can view
7. Return `image_url`

**Request:**

```
POST /functions/v1/upload-to-drive
Authorization: Bearer <jwt_token>
Content-Type: multipart/form-data

file: <binary>
pegawai_nama: "Budi Santoso"
tanggal: "2026-05-04"
filename: "foto_20260504_143022.jpg"
```

**Response:**

```json
{ "image_url": "https://drive.google.com/uc?export=view&id=xxx" }
```

**Secrets yang dibutuhkan:**

- `SERVICE_ROLE_KEY`
- `GOOGLE_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PRIVATE_KEY`
- `GOOGLE_DRIVE_ROOT_FOLDER_ID`

## Cara Memanggil dari Flutter

```dart
final response = await _client.functions.invoke(
  'admin-create-user',
  body: { 'nama': nama, 'email': email, ... },
);

if (response.status != 200) {
  final data = response.data as Map<String, dynamic>?;
  throw AppException(data?['error'] ?? 'Gagal');
}
```

## 4.5 image-proxy

**File:** `supabase/functions/image-proxy/index.ts`

**Deploy command:**

```bash
supabase functions deploy image-proxy --project-ref <project_ref>
```

> ℹ️ JWT verification dimatikan via Supabase Dashboard → Edge Functions → image-proxy → Settings → **Verify JWT with legacy secret: OFF**. Request tetap membutuhkan `Authorization: Bearer <token>` yang dikirim dari Flutter.

**Alur:**

1. Terima query param `?id=<google_drive_file_id>`
2. Verifikasi `Authorization: Bearer <token>` header (anon key atau session token)
3. Generate Google access token via **Service Account JWT** (bukan OAuth refresh token)
4. Fetch file dari Google Drive API menggunakan access token tersebut
5. Return bytes gambar ke client dengan `Cache-Control: public, max-age=86400`

**Kegunaan:**

- Menampilkan gambar Google Drive di Flutter Web (menghindari CORS)
- Mengakses file yang tidak di-share publik (service account punya akses ke semua file di Drive)
- Cache 1 hari

**Cara pemanggilan dari Flutter:**

```dart
// Mobile: Image.network dengan header Authorization
final proxyUrl = '${SupabaseConstants.imageProxyUrl}?id=$fileId';
Image.network(proxyUrl, headers: {'Authorization': 'Bearer $token'}, ...);

// Web: fetch manual via http.get dengan Authorization header
// (CachedNetworkImage tidak support custom headers di web)
final response = await http.get(
  Uri.parse('${SupabaseConstants.imageProxyUrl}?id=$fileId'),
  headers: {'Authorization': 'Bearer $token'},
);
Image.memory(response.bodyBytes, ...);
```

Widget `DriveImage` menangani perbedaan ini secara otomatis — di web menggunakan `_WebDriveImage` yang fetch manual, di mobile menggunakan `Image.network`.

**Secrets yang dibutuhkan:**

- `GOOGLE_SERVICE_ACCOUNT_EMAIL`
- `GOOGLE_PRIVATE_KEY`

> ⚠️ Sebelumnya menggunakan OAuth refresh token (`GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REFRESH_TOKEN`). Sudah diganti ke Service Account karena refresh token bisa expired.

**Kenapa tidak pakai `lh3.googleusercontent.com` atau `uc?export=view`:**

| Metode                                      | Masalah                                                                      |
| ------------------------------------------- | ---------------------------------------------------------------------------- |
| `lh3.googleusercontent.com/d/{ID}`          | Rate limit 429 saat banyak gambar dimuat sekaligus                           |
| `drive.google.com/uc?export=view&id={ID}`   | CORS error di Flutter Web — Google redirect ke domain lain tanpa CORS header |
| `image-proxy` tanpa auth header             | 401 dari Supabase Gateway                                                    |
| `image-proxy` dengan `Authorization` header | ✅ Berfungsi — tidak ada CORS, tidak ada rate limit, bisa akses file private |

## 4.6 import-from-sheets

**File:** `supabase/functions/import-from-sheets/index.ts`

**Alur:**

1. Verifikasi JWT caller → cek role = 'admin'
2. Parse body: `{ targetTable, rows[] }`
3. Validasi `targetTable` hanya boleh: `users`, `kegiatan`, `laporan`, `dokumentasi`
4. Upsert setiap baris ke tabel tujuan, tangkap error per baris
5. Return statistik: `{ success, imported, failed, errors[] }`

**Request:**

```json
POST /functions/v1/import-from-sheets
Authorization: Bearer <jwt_token>

{
  "targetTable": "dokumentasi",
  "rows": [
    {
      "user_id": "uuid",
      "proyek": "Nama Proyek",
      "tanggal_kegiatan": "2025-07-07",
      "catatan": "...",
      "image_url": "https://drive.google.com/..."
    }
  ]
}
```

**Response:**

```json
{ "success": true, "imported": 95, "failed": 5, "errors": [...] }
```

**Catatan:** Digunakan oleh fitur Import Data Spreadsheet (admin-only) dan script migrasi `scripts/migrate-from-sheets.js`.
