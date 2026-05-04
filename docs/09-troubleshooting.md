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
