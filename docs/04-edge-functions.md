# Tahap 4 — Supabase Edge Functions

Edge Functions adalah server-side code yang berjalan di Deno runtime. Digunakan untuk operasi yang membutuhkan service role key atau credentials sensitif.

## Daftar Edge Functions

| Function               | Path                                 | Kegunaan                    |
| ---------------------- | ------------------------------------ | --------------------------- |
| `admin-create-user`    | `/functions/v1/admin-create-user`    | Buat akun pegawai baru      |
| `admin-delete-user`    | `/functions/v1/admin-delete-user`    | Hapus akun pegawai          |
| `admin-reset-password` | `/functions/v1/admin-reset-password` | Ubah password pegawai       |
| `upload-to-drive`      | `/functions/v1/upload-to-drive`      | Upload foto ke Google Drive |

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
