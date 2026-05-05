# Tahap 9 — Troubleshooting

Kumpulan masalah yang ditemui selama pengembangan beserta solusinya.

---

## ❌ Failed to fetch (statusCode: null)

**Gejala:**

```
AppException: AuthRetryableFetchException(message: ClientException: Failed to fetch,
uri=https://xxx.supabase.co/auth/v1/token, statusCode: null)
```

**Penyebab:** CORS block di browser saat Flutter Web berjalan di localhost.

**Solusi development:**

```bash
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

**Solusi production:** Tidak perlu — iOS/Android tidak punya masalah CORS.

---

## ❌ URL Supabase salah (typo)

**Gejala:** Error fetch ke `your_project_id.supabase.co` (masih placeholder).

**Penyebab:** File `supabase_constants.dart` belum diisi, atau URL yang diisi salah.

**Solusi:** Cek URL di Supabase Dashboard → Settings → API. Perhatikan typo (contoh: `glywzobifjordhwulpbw` vs `glywzqbifjordhwulpbw` — huruf `o` vs `q`).

---

## ❌ Publishable key tidak kompatibel

**Gejala:** Login gagal meski URL benar.

**Penyebab:** `supabase_flutter ^2.x` belum support format key baru `sb_publishable_...`.

**Solusi:** Gunakan **Legacy anon key** dari tab "Legacy anon, service_role API keys" di Settings → API Keys.

---

## ❌ LocaleDataException

**Gejala:**

```
LocaleDataException: Locale data has not been initialized,
call initializeDateFormatting(<locale>).
```

**Penyebab:** `DateFormat('d MMMM yyyy', 'id_ID')` dipanggil sebelum locale diinisialisasi.

**Solusi:** Tambahkan di `main.dart`:

```dart
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null); // ← tambahkan ini
  await Supabase.initialize(...);
  runApp(...);
}
```

---

## ❌ Ambiguous import: AuthUser / AuthException / StorageException

**Gejala:** Error compile `The name 'AuthUser' is defined in the libraries...`

**Penyebab:** `supabase_flutter` mengekspor class dengan nama yang sama dengan class kita.

**Solusi:**

```dart
// Rename class kita
class AppAuthUser { ... }  // bukan AuthUser

// Hide import yang bentrok
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, StorageException;
```

---

## ❌ Method update() conflict dengan AsyncNotifierBase

**Gejala:** Error `'PegawaiNotifier.update' isn't a valid override of 'AsyncNotifierBase.update'`

**Penyebab:** Riverpod `AsyncNotifier` sudah punya method `update()` bawaan.

**Solusi:** Rename method menjadi `updatePegawai()`, `updateKegiatan()`, dll.

---

## ❌ Duplicate key saat tambah pegawai

**Gejala:**

```
Gagal insert profil: duplicate key value violates unique constraint "users_pkey"
```

**Penyebab:** Trigger `handle_new_user` sudah otomatis insert ke tabel `users` saat auth user dibuat. Edge Function kemudian mencoba insert lagi.

**Solusi:** Ganti `INSERT` menjadi `UPDATE` di Edge Function, dengan delay 500ms:

```typescript
await new Promise((resolve) => setTimeout(resolve, 500))
const { data } = await adminClient.from("users").update({...}).eq("id", userId)
```

---

## ❌ Secret name tidak boleh prefix SUPABASE\_

**Gejala:** Error saat menyimpan secret di Supabase Dashboard: `Name must not start with the SUPABASE_ prefix`

**Penyebab:** Supabase mereservasi prefix `SUPABASE_` untuk secret bawaan.

**Solusi:** Gunakan nama `SERVICE_ROLE_KEY` (tanpa prefix `SUPABASE_`).

---

## ❌ Edge Function 500 error

**Gejala:** Function crash dengan status 500.

**Cara debug:**

1. Buka Supabase Dashboard → Edge Functions → klik nama function
2. Klik tab **"Logs"** untuk lihat error detail
3. Atau klik tab **"Invocations"** untuk lihat request/response

**Penyebab umum:**

- Secret tidak ditemukan (`Deno.env.get("SERVICE_ROLE_KEY")` return undefined)
- Syntax error di kode TypeScript
- Network error ke Supabase API

---

## ❌ Flutter Web blank page setelah login

**Gejala:** Halaman putih setelah berhasil login.

**Penyebab:** Runtime error di provider/widget, biasanya locale belum diinisialisasi.

**Solusi:** Lihat error di browser DevTools (F12 → Console), atau cek output terminal Flutter.

---

## ❌ CardTheme vs CardThemeData

**Gejala:** Error `The argument type 'CardTheme' can't be assigned to the parameter type 'CardThemeData?'`

**Penyebab:** Flutter 3.x mengubah tipe parameter di `ThemeData`.

**Solusi:** Ganti `CardTheme(...)` menjadi `CardThemeData(...)`.

---

## ❌ withOpacity deprecated

**Gejala:** Warning `'withOpacity' is deprecated and shouldn't be used`

**Solusi:** Ganti `color.withOpacity(0.1)` menjadi `color.withValues(alpha: 0.1)`.

---

## ❌ Gambar dokumentasi tidak muncul (hanya milik sendiri)

**Gejala:** Di halaman Dokumentasi, hanya gambar milik user yang login yang muncul. Gambar pegawai lain tidak tampil (placeholder icon).

**Penyebab:** RLS policy `dokumentasi_self` hanya mengizinkan `auth.uid() = user_id`, sehingga pegawai tidak bisa membaca dokumentasi milik orang lain. Selain itu, JOIN ke tabel `users` juga dibatasi RLS sehingga `pegawaiNama` selalu null untuk dokumentasi orang lain.

**Solusi:**

1. Tambah kolom `pegawai_nama` di tabel `dokumentasi` dan isi dari data `users`
2. Update RLS `dokumentasi` agar semua authenticated user bisa baca semua dokumentasi
3. Update RLS `users` agar semua authenticated user bisa baca semua profil

Lihat SQL lengkap di `02-database-schema.md` bagian 2.4.

---

## ❌ Gambar dokumentasi 429 Too Many Requests

**Gejala:** Gambar tidak muncul, DevTools Network menunjukkan status 429 dari `lh3.googleusercontent.com`.

**Penyebab:** Saat halaman Dokumentasi memuat banyak gambar sekaligus, Google membatasi request dari satu IP (rate limiting). URL format `lh3.googleusercontent.com/d/{FILE_ID}=s800` rentan kena rate limit.

**Solusi:** Gunakan `image-proxy` Supabase untuk semua gambar. Proxy fetch dari Google Drive menggunakan service account (bukan browser langsung), sehingga tidak ada rate limit dari sisi client.

---

## ❌ Gambar dokumentasi CORS error (`uc?export=view`)

**Gejala:** Console browser menampilkan `Access to XMLHttpRequest ... has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header`.

**Penyebab:** URL `drive.google.com/uc?export=view&id=...` melakukan redirect ke `drive.usercontent.google.com` yang tidak punya CORS header. Browser memblokir ini untuk request dari `Image.network` di Flutter Web.

**Solusi:** Gunakan `image-proxy` Supabase — proxy berjalan di server, tidak ada CORS issue.

---

## ❌ image-proxy 401 Unauthorized (`UNAUTHORIZED_NO_AUTH_HEADER`)

**Gejala:** Request ke `image-proxy` mengembalikan 401 meskipun kode function tidak mewajibkan auth.

**Penyebab:** Supabase Edge Functions secara default memerlukan JWT di level **platform** (Supabase Gateway), bukan hanya di kode function. Meskipun kode function tidak cek auth, Gateway tetap memblokir request tanpa token.

**Solusi:** Deploy function dengan flag `--no-verify-jwt`:

```bash
supabase functions deploy image-proxy --no-verify-jwt --project-ref <project_ref>
```

> ⚠️ Jangan lupa flag ini setiap kali re-deploy `image-proxy`. Tanpa flag ini, gambar tidak akan muncul di Flutter Web.
