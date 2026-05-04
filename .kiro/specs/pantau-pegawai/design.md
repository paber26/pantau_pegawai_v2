# Design Document: PantauPegawai

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                          │
│  ┌──────────────────────┐    ┌──────────────────────────┐   │
│  │  Flutter Android      │    │  Flutter Web/Desktop      │   │
│  │  (Pegawai App)        │    │  (Admin Dashboard)        │   │
│  └──────────┬───────────┘    └────────────┬─────────────┘   │
└─────────────┼──────────────────────────────┼─────────────────┘
              │                              │
              ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      SUPABASE BACKEND                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │   Auth   │  │PostgreSQL│  │ Realtime │  │Edge Funcs  │  │
│  └──────────┘  └──────────┘  └──────────┘  └─────┬──────┘  │
└──────────────────────────────────────────────────┼──────────┘
                                                   │
                                                   ▼
                                        ┌──────────────────┐
                                        │   Google Drive   │
                                        │  (File Storage)  │
                                        └──────────────────┘
```

## Project Structure

```
pantau_pegawai/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_strings.dart
│   │   │   └── supabase_constants.dart
│   │   ├── errors/
│   │   │   └── app_exception.dart
│   │   ├── router/
│   │   │   └── app_router.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       ├── date_utils.dart
│   │       └── validators.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── auth_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   └── auth_state.dart
│   │   │   └── presentation/
│   │   │       ├── login_screen.dart
│   │   │       └── auth_provider.dart
│   │   ├── pegawai/
│   │   │   ├── data/
│   │   │   │   ├── pegawai_repository.dart
│   │   │   │   └── pegawai_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   └── pegawai_model.dart
│   │   │   └── presentation/
│   │   │       ├── pegawai_list_screen.dart
│   │   │       ├── pegawai_form_screen.dart
│   │   │       └── pegawai_provider.dart
│   │   ├── kegiatan/
│   │   │   ├── data/
│   │   │   │   ├── kegiatan_repository.dart
│   │   │   │   └── kegiatan_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   └── kegiatan_model.dart
│   │   │   └── presentation/
│   │   │       ├── kegiatan_list_screen.dart
│   │   │       ├── kegiatan_detail_screen.dart
│   │   │       ├── kegiatan_form_screen.dart
│   │   │       └── kegiatan_provider.dart
│   │   ├── penugasan/
│   │   │   ├── data/
│   │   │   │   ├── penugasan_repository.dart
│   │   │   │   └── penugasan_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   └── penugasan_model.dart
│   │   │   └── presentation/
│   │   │       ├── assign_screen.dart
│   │   │       └── penugasan_provider.dart
│   │   ├── laporan/
│   │   │   ├── data/
│   │   │   │   ├── laporan_repository.dart
│   │   │   │   └── laporan_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   └── laporan_model.dart
│   │   │   └── presentation/
│   │   │       ├── upload_laporan_screen.dart
│   │   │       ├── laporan_list_screen.dart
│   │   │       ├── laporan_detail_screen.dart
│   │   │       └── laporan_provider.dart
│   │   └── dashboard/
│   │       ├── domain/
│   │       │   └── dashboard_stats_model.dart
│   │       └── presentation/
│   │           ├── admin_dashboard_screen.dart
│   │           └── dashboard_provider.dart
│   └── shared/
│       ├── widgets/
│       │   ├── app_button.dart
│       │   ├── app_text_field.dart
│       │   ├── loading_overlay.dart
│       │   ├── error_widget.dart
│       │   ├── stat_card.dart
│       │   └── admin_sidebar.dart
│       └── providers/
│           └── supabase_provider.dart
├── supabase/
│   ├── migrations/
│   │   └── 001_initial_schema.sql
│   └── functions/
│       └── upload-to-drive/
│           └── index.ts
├── pubspec.yaml
└── README.md
```

## State Management (Riverpod)

Setiap fitur memiliki provider sendiri menggunakan `AsyncNotifier` / `StateNotifier`:

```
AuthNotifier        → session state, login, logout
PegawaiNotifier     → CRUD pegawai
KegiatanNotifier    → CRUD kegiatan
PenugasanNotifier   → assign/unassign
LaporanNotifier     → upload, list, detail
DashboardNotifier   → statistik realtime
```

## Navigation / Routing (go_router)

```
/login                          → LoginScreen
/                               → redirect berdasarkan role
/admin
  /admin/dashboard              → AdminDashboardScreen
  /admin/pegawai                → PegawaiListScreen
  /admin/pegawai/tambah         → PegawaiFormScreen
  /admin/pegawai/:id/edit       → PegawaiFormScreen (edit)
  /admin/kegiatan               → KegiatanListScreen
  /admin/kegiatan/tambah        → KegiatanFormScreen
  /admin/kegiatan/:id/edit      → KegiatanFormScreen (edit)
  /admin/kegiatan/:id/assign    → AssignScreen
  /admin/laporan                → LaporanListScreen (admin view)
  /admin/laporan/:id            → LaporanDetailScreen
/pegawai
  /pegawai/kegiatan             → KegiatanListScreen (pegawai view)
  /pegawai/kegiatan/:id         → KegiatanDetailScreen
  /pegawai/kegiatan/:id/upload  → UploadLaporanScreen
  /pegawai/riwayat              → LaporanListScreen (pegawai view)
  /pegawai/riwayat/:id          → LaporanDetailScreen
```

## Google Drive Integration via Edge Function

### Flow Upload Foto

```
Flutter App
  │
  ├─ 1. Ambil foto (image_picker)
  ├─ 2. Kirim multipart/form-data ke Edge Function
  │      POST /functions/v1/upload-to-drive
  │      Headers: Authorization: Bearer <supabase_jwt>
  │      Body: { file: <bytes>, pegawai_nama, tanggal, filename }
  │
Supabase Edge Function (Deno)
  ├─ 3. Verifikasi JWT Supabase
  ├─ 4. Authenticate ke Google Drive API (Service Account)
  ├─ 5. Buat folder jika belum ada: /PantauPegawai/{nama}/{yyyy-mm-dd}/
  ├─ 6. Upload file ke folder tersebut
  ├─ 7. Set permission: anyone with link can view
  └─ 8. Return { image_url: "https://drive.google.com/..." }
  │
Flutter App
  └─ 9. Simpan metadata ke tabel laporan di Supabase
```

### Edge Function Environment Variables

```
GOOGLE_SERVICE_ACCOUNT_EMAIL
GOOGLE_PRIVATE_KEY
GOOGLE_DRIVE_ROOT_FOLDER_ID
```

## UI Design Decisions

### Mobile (Pegawai)

- Bottom navigation: Kegiatan | Riwayat | Profil
- Card-based list untuk kegiatan dan laporan
- FAB untuk upload laporan
- Status badge: Belum Upload / Sudah Upload

### Web/Desktop (Admin)

- Persistent sidebar navigation
- Data table dengan sorting dan filter
- Modal dialog untuk form CRUD
- Stats card di dashboard
- Realtime badge counter untuk laporan baru

## Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Backend
  supabase_flutter: ^2.5.0

  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^13.2.0

  # Image
  image_picker: ^1.1.2
  cached_network_image: ^3.3.1

  # UI
  flutter_svg: ^2.0.10+1
  intl: ^0.19.0

  # Utils
  uuid: ^4.4.0
  http: ^1.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
```

## Supabase Edge Function: upload-to-drive

```typescript
// supabase/functions/upload-to-drive/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const GOOGLE_SERVICE_ACCOUNT_EMAIL = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_EMAIL")!
const GOOGLE_PRIVATE_KEY = Deno.env.get("GOOGLE_PRIVATE_KEY")!.replace(/\\n/g, "\n")
const ROOT_FOLDER_ID = Deno.env.get("GOOGLE_DRIVE_ROOT_FOLDER_ID")!

// JWT untuk Google Service Account
async function getGoogleAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const header = { alg: "RS256", typ: "JWT" }
  const payload = {
    iss: GOOGLE_SERVICE_ACCOUNT_EMAIL,
    scope: "https://www.googleapis.com/auth/drive",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now
  }
  // ... sign JWT dengan private key dan exchange ke access token
}

serve(async (req) => {
  // Verifikasi Supabase JWT
  // Parse multipart form data
  // Upload ke Google Drive
  // Return image_url
})
```

## Security Considerations

1. **RLS** aktif di semua tabel — pegawai tidak bisa akses data pegawai lain.
2. **Edge Function** adalah satu-satunya tempat Google credentials berada.
3. **Service Role Key** hanya di Edge Function, tidak pernah di client.
4. **CORS** dikonfigurasi di Edge Function untuk hanya menerima dari domain yang diizinkan.
5. **Input validation** di semua form sebelum dikirim ke Supabase.
