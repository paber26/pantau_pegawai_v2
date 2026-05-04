# Tahap 1 — Setup Project Flutter

## 1.1 Membuat Project

Project dibuat menggunakan Flutter CLI dengan nama `pantau_pegawai`.

Web support ditambahkan setelah project dibuat:

```bash
flutter create . --platforms=web
```

## 1.2 Dependencies (pubspec.yaml)

```yaml
dependencies:
  supabase_flutter: ^2.8.4 # Backend Supabase
  flutter_riverpod: ^2.5.1 # State management
  riverpod_annotation: ^2.3.5 # Code generation untuk Riverpod
  go_router: ^13.2.5 # Navigation
  image_picker: ^1.1.2 # Kamera & galeri
  cached_network_image: ^3.3.1
  intl: ^0.19.0 # Format tanggal Indonesia
  http: ^1.2.1 # HTTP client untuk Edge Functions
  url_launcher: ^6.3.0 # Buka link eksternal
  shimmer: ^3.0.0

dev_dependencies:
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
```

## 1.3 Struktur Folder (Feature-Based Clean Architecture)

```
lib/
├── main.dart                    # Entry point, init Supabase & locale
├── app.dart                     # MaterialApp.router
├── core/
│   ├── constants/
│   │   ├── app_colors.dart      # Palet warna aplikasi
│   │   ├── app_strings.dart     # String/label UI
│   │   └── supabase_constants.dart  # ⚠️ TIDAK di-commit (credentials)
│   ├── errors/
│   │   └── app_exception.dart   # Custom exception classes
│   ├── router/
│   │   └── app_router.dart      # go_router dengan role-based redirect
│   ├── theme/
│   │   └── app_theme.dart       # Material 3 theme
│   └── utils/
│       ├── date_utils.dart      # Format tanggal Indonesia
│       └── validators.dart      # Form validators
├── features/
│   ├── auth/                    # Login, logout, session
│   ├── pegawai/                 # CRUD pegawai
│   ├── kegiatan/                # CRUD kegiatan
│   ├── penugasan/               # Assign kegiatan ke pegawai
│   ├── laporan/                 # Upload & lihat laporan (legacy)
│   ├── dokumentasi/             # Dokumentasi harian (fitur utama)
│   └── dashboard/               # Statistik admin
└── shared/
    └── widgets/                 # Komponen UI reusable
```

## 1.4 Generate Riverpod Code

Setiap kali menambah/mengubah provider dengan `@riverpod` annotation:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 1.5 iOS Permissions (Info.plist)

Ditambahkan ke `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Aplikasi membutuhkan akses kamera untuk mengambil foto laporan kegiatan.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Aplikasi membutuhkan akses galeri untuk memilih foto laporan kegiatan.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Aplikasi membutuhkan akses untuk menyimpan foto ke galeri.</string>
```

## 1.6 Inisialisasi Locale Indonesia

Di `main.dart`, tambahkan sebelum `runApp()`:

```dart
await initializeDateFormatting('id_ID', null);
```

Tanpa ini akan muncul error: `LocaleDataException: Locale data has not been initialized`.
