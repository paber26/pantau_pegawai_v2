# Rencana Implementasi: Google Sheets Data Import

## Ikhtisar

Implementasi fitur migrasi data historis dari Google Spreadsheet ke Supabase melalui wizard 5 langkah. Fitur ini bersifat admin-only dan mengikuti arsitektur yang sudah ada: Repository pattern, Riverpod (`riverpod_annotation` + `build_runner`), dan GoRouter.

Bahasa implementasi: **Dart / Flutter** (frontend) + **TypeScript / Deno** (Edge Function).

---

## Tasks

- [x] 1. Buat domain models untuk fitur import sheets
  - Buat file `lib/features/import_sheets/domain/sheet_metadata_model.dart` dengan class `SheetMetadataModel` (field: `sheetId`, `title`, `index`) beserta factory `fromMap`.
  - Buat file `lib/features/import_sheets/domain/sheet_row_model.dart` dengan class `SheetRowModel` (field: `rowIndex`, `values`).
  - Buat file `lib/features/import_sheets/domain/column_mapping_model.dart` dengan class `ColumnMappingModel` (field: `sourceColumn`, `targetColumn`, `isIgnored`) dan class `ColumnDefinition` (field: `name`, `type`, `required`).
  - Buat file `lib/features/import_sheets/domain/validation_result_model.dart` dengan class `ValidationResultModel` (field: `totalRows`, `validRows`, `invalidRows`, `errors`) dan class `RowValidationError` (field: `rowIndex`, `columnName`, `value`, `message`).
  - Buat file `lib/features/import_sheets/domain/import_result_model.dart` dengan class `ImportResultModel` (field: `totalProcessed`, `successCount`, `failedCount`, `duration`, `errors`) dan class `ImportRowError` (field: `rowIndex`, `originalData`, `message`).
  - Buat file `lib/features/import_sheets/domain/table_schema_config.dart` dengan konstanta `kSupabaseTableSchemas` yang mendefinisikan skema kolom untuk tabel `users`, `kegiatan`, `laporan`, dan `dokumentasi`. Kolom `image_url` pada tabel `laporan` dan `dokumentasi` bertipe `text` dan tidak required — nilai diisi langsung dari URL/link Drive yang sudah ada di spreadsheet (tidak perlu upload ulang).
  - _Requirements: 1.1, 1.2, 4.2, 4.3, 5.1_

- [-] 2. Buat helper functions untuk validasi dan transformasi data
  - [x] 2.1 Implementasi fungsi `extractSpreadsheetId(String input)` di `lib/features/import_sheets/domain/spreadsheet_id_extractor.dart`
    - Fungsi menerima URL lengkap Google Spreadsheet atau Spreadsheet ID langsung.
    - Jika input adalah URL dengan format `https://docs.google.com/spreadsheets/d/{ID}/...`, ekstrak dan kembalikan `{ID}`.
    - Jika input adalah string tanpa `/` dan tidak kosong, anggap sebagai ID langsung dan kembalikan as-is.
    - Jika input tidak valid (kosong, URL domain lain, format salah), kembalikan `null`.
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [ ] 2.2 Tulis property test untuk `extractSpreadsheetId`
    - **Property 1: Ekstraksi Spreadsheet ID dari URL**
    - Gunakan `fast_check`: generate string acak sebagai `spreadsheetId`, buat URL `https://docs.google.com/spreadsheets/d/$spreadsheetId/edit`, verifikasi hasil ekstraksi sama dengan `spreadsheetId`.
    - **Validates: Requirements 1.2, 1.5**

  - [ ] 2.3 Tulis property test untuk penolakan input tidak valid
    - **Property 2: Penolakan Input Tidak Valid**
    - Gunakan `fast_check`: generate string yang bukan URL Google Sheets valid dan bukan ID valid (string kosong, URL domain lain), verifikasi `extractSpreadsheetId` mengembalikan `null`.
    - **Validates: Requirements 1.4**

  - [x] 2.4 Implementasi fungsi `limitPreviewRows(List<SheetRowModel> rows)` di `lib/features/import_sheets/domain/preview_utils.dart`
    - Kembalikan maksimal 10 baris pertama dari list.
    - _Requirements: 3.1_

  - [ ] 2.5 Tulis property test untuk `limitPreviewRows`
    - **Property 3: Pratinjau Dibatasi Maksimal 10 Baris**
    - Gunakan `fast_check`: generate integer `rowCount` antara 0–200, buat list `SheetRowModel` sebanyak `rowCount`, verifikasi `limitPreviewRows` mengembalikan `min(rowCount, 10)` baris.
    - **Validates: Requirements 3.1**

  - [ ] 2.6 Tulis property test untuk jumlah baris data akurat
    - **Property 4: Jumlah Baris Data Akurat**
    - Gunakan `fast_check`: generate integer `totalRows` (termasuk header), verifikasi bahwa jumlah baris data = `totalRows - 1`.
    - **Validates: Requirements 3.3**

  - [x] 2.7 Implementasi fungsi `validateRows(List<SheetRowModel> rows, List<ColumnMappingModel> mappings, String targetTable)` di `lib/features/import_sheets/domain/row_validator.dart`
    - Validasi setiap baris: kolom required tidak boleh kosong, kolom bertipe `date` harus dapat diparse.
    - Kembalikan `ValidationResultModel`.
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ] 2.8 Tulis property test untuk konsistensi jumlah validasi
    - **Property 6: Konsistensi Jumlah Validasi**
    - Gunakan `fast_check`: generate list baris data acak, verifikasi `result.validRows + result.invalidRows == rows.length`.
    - **Validates: Requirements 5.4**

  - [ ] 2.9 Tulis property test untuk validasi tanggal
    - **Property 7: Validasi Tanggal Menolak Format Tidak Valid**
    - Gunakan `fast_check`: generate string yang bukan tanggal ISO 8601 atau format umum, verifikasi fungsi validasi tanggal mengklasifikasikan sebagai error.
    - **Validates: Requirements 5.2**

  - [ ] 2.10 Tulis property test untuk validasi kolom required
    - **Property 8: Validasi Kolom Required Menolak Nilai Kosong**
    - Gunakan `fast_check`: generate baris dengan nilai kosong pada kolom required, verifikasi baris diklasifikasikan sebagai invalid.
    - **Validates: Requirements 5.3**

  - [x] 2.11 Implementasi fungsi `splitIntoBatches<T>(List<T> items, {int batchSize = 100})` di `lib/features/import_sheets/domain/batch_utils.dart`
    - Bagi list menjadi sub-list dengan ukuran maksimal `batchSize`.
    - _Requirements: 6.4_

  - [ ] 2.12 Tulis property test untuk ukuran batch
    - **Property 9: Ukuran Batch Tidak Melebihi 100**
    - Gunakan `fast_check`: generate integer `rowCount` antara 1–1000, verifikasi setiap batch ≤ 100 baris dan total baris di semua batch = `rowCount`.
    - **Validates: Requirements 6.4**

  - [ ] 2.13 Tulis property test untuk peringatan kolom required tidak dipetakan
    - **Property 5: Peringatan Kolom Required Tidak Dipetakan**
    - Gunakan `fast_check`: generate konfigurasi pemetaan di mana setidaknya satu kolom required tidak dipetakan, verifikasi fungsi `hasUnmappedRequiredColumns` mengembalikan `true`.
    - **Validates: Requirements 4.6**

- [x] 3. Checkpoint — Pastikan semua unit test dan property test untuk domain layer lulus
  - Pastikan semua tests lulus, tanyakan kepada user jika ada pertanyaan.

- [-] 4. Buat repository interface dan implementasi
  - [x] 4.1 Buat abstract class `ImportSheetsRepository` di `lib/features/import_sheets/data/import_sheets_repository.dart`
    - Definisikan method: `getSheetList(String spreadsheetId)`, `getSheetData(String spreadsheetId, String sheetName)`, `importBatch({required String targetTable, required List<Map<String, dynamic>> rows, required String jwtToken})`.
    - _Requirements: 2.1, 3.1, 6.1_

  - [x] 4.2 Buat `ImportSheetsRepositoryImpl` di `lib/features/import_sheets/data/import_sheets_repository_impl.dart`
    - Implementasi `getSheetList`: panggil `GET https://sheets.googleapis.com/v4/spreadsheets/{id}?key={API_KEY}&fields=sheets.properties`, parse response menjadi `List<SheetMetadataModel>`.
    - Implementasi `getSheetData`: panggil `GET https://sheets.googleapis.com/v4/spreadsheets/{id}/values/{sheetName}?key={API_KEY}`, parse baris pertama sebagai header, baris berikutnya sebagai data `SheetRowModel`.
    - Implementasi `importBatch`: panggil `POST {SUPABASE_URL}/functions/v1/import-from-sheets` dengan header `Authorization: Bearer {jwtToken}` dan body JSON `{targetTable, rows}`.
    - Tambahkan konstanta `importSheetsFunctionUrl` di `lib/core/constants/supabase_constants.dart`.
    - Tambahkan konstanta `googleSheetsApiKey` di `lib/core/constants/supabase_constants.dart` (baca dari `String.fromEnvironment('GOOGLE_SHEETS_API_KEY')`).
    - Terapkan `withRetry` (maks 3x, jeda 2 detik) untuk semua HTTP call ke Google Sheets API.
    - Terapkan timeout 30 detik untuk Sheets API dan 60 detik untuk Edge Function.
    - _Requirements: 2.1, 2.3, 2.4, 3.1, 6.1, 9.3, 9.4, 9.5_

  - [ ] 4.3 Tulis unit test untuk `ImportSheetsRepositoryImpl`
    - Test `getSheetList` dengan mock HTTP response sukses, 404, 403, dan timeout.
    - Test `getSheetData` dengan sheet kosong, hanya header, dan sheet dengan data.
    - Test `importBatch` dengan mock Edge Function response sukses dan error.
    - _Requirements: 2.3, 2.4, 9.1, 9.3_

- [x] 5. Buat Edge Function `import-from-sheets`
  - Buat file `supabase/functions/import-from-sheets/index.ts`.
  - Verifikasi JWT dari header `Authorization: Bearer {token}` menggunakan Supabase Admin client.
  - Ambil role user dari tabel `users` dan tolak dengan HTTP 403 jika bukan `admin`.
  - Parse body JSON: `{ targetTable: string, rows: Record<string, unknown>[] }`.
  - Proses setiap baris dengan `upsert` ke tabel yang sesuai, tangkap error per baris tanpa menghentikan proses.
  - Kembalikan response JSON: `{ success: true, imported: number, failed: number, errors: ImportRowError[] }`.
  - Terapkan CORS headers untuk mendukung request dari Flutter Web.
  - _Requirements: 6.2, 6.5, 8.3, 8.4, 8.5_

- [x] 6. Buat Riverpod provider untuk state wizard
  - Buat file `lib/features/import_sheets/presentation/import_sheets_provider.dart`.
  - Definisikan `ImportWizardState` dengan field: `currentStep` (int 1–5), `spreadsheetId` (String?), `sheetList` (List<SheetMetadataModel>), `selectedSheet` (String?), `previewRows` (List<SheetRowModel>), `targetTable` (String?), `columnMappings` (List<ColumnMappingModel>), `validationResult` (ValidationResultModel?), `importResult` (ImportResultModel?), `isLoading` (bool), `errorMessage` (String?).
  - Implementasi `ImportSheetsNotifier extends _$ImportSheetsNotifier` dengan method: `setSpreadsheetId`, `loadSheetList`, `selectSheet`, `setTargetTable`, `updateMapping`, `runValidation`, `startImport`, `reset`.
  - Tambahkan provider `importSheetsRepositoryProvider` yang menyediakan `ImportSheetsRepositoryImpl`.
  - Jalankan `dart run build_runner build --delete-conflicting-outputs` untuk generate file `.g.dart`.
  - _Requirements: 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 6.3, 7.1_

- [x] 7. Buat UI wizard — Langkah 1: Konfigurasi Sumber
  - Buat file `lib/features/import_sheets/presentation/steps/step1_configure_screen.dart`.
  - Tampilkan `TextField` untuk input URL atau Spreadsheet ID.
  - Validasi input secara real-time menggunakan `extractSpreadsheetId`; tampilkan pesan error inline jika tidak valid.
  - Tombol "Lanjut" memanggil `notifier.loadSheetList()` dan berpindah ke langkah 2 jika berhasil.
  - Tampilkan `CircularProgressIndicator` saat loading dan pesan error jika gagal (404, 403, timeout).
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.3, 2.4_

- [x] 8. Buat UI wizard — Langkah 2: Pratinjau Data
  - Buat file `lib/features/import_sheets/presentation/steps/step2_preview_screen.dart`.
  - Tampilkan daftar sheet yang tersedia sebagai pilihan (chip atau radio button).
  - Saat sheet dipilih, panggil `notifier.selectSheet()` untuk memuat data pratinjau.
  - Tampilkan tabel pratinjau (maks 10 baris) dengan header kolom dari baris pertama sheet.
  - Tampilkan jumlah total baris data (tidak termasuk header).
  - Tampilkan pesan informasi jika sheet kosong atau hanya berisi header.
  - Tombol "Kembali" dan "Lanjut ke Pemetaan".
  - _Requirements: 2.2, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 9. Buat UI wizard — Langkah 3: Pemetaan Kolom
  - Buat file `lib/features/import_sheets/presentation/steps/step3_mapping_screen.dart`.
  - Tampilkan dropdown untuk memilih tabel tujuan (`users`, `kegiatan`, `laporan`, `dokumentasi`).
  - Untuk setiap kolom sumber dari sheet, tampilkan baris pemetaan dengan dropdown kolom tujuan (dari `kSupabaseTableSchemas`) dan opsi "Abaikan".
  - Tampilkan badge/indikator pada kolom tujuan yang bertipe `required`.
  - Tampilkan peringatan jika ada kolom required yang belum dipetakan.
  - Tombol "Kembali" dan "Konfirmasi Pemetaan".
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7_

- [x] 10. Buat UI wizard — Langkah 4: Validasi Data
  - Buat file `lib/features/import_sheets/presentation/steps/step4_validation_screen.dart`.
  - Saat layar ditampilkan, jalankan `notifier.runValidation()` secara otomatis.
  - Tampilkan ringkasan validasi: total baris, baris valid, baris dengan error.
  - Tampilkan daftar error per baris (nomor baris, nama kolom, nilai, pesan error) jika ada.
  - Tombol "Mulai Impor" hanya aktif jika ada baris valid; tampilkan konfirmasi dialog sebelum impor dimulai.
  - Tombol "Kembali ke Pemetaan".
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [x] 11. Buat UI wizard — Langkah 5: Hasil Impor
  - Buat file `lib/features/import_sheets/presentation/steps/step5_result_screen.dart`.
  - Tampilkan indikator progres (linear progress bar) saat impor berlangsung, dengan persentase baris yang sudah diproses.
  - Setelah selesai, tampilkan statistik: total diproses, berhasil, gagal, durasi.
  - Tampilkan daftar baris gagal (nomor baris, data asli, pesan error) jika ada.
  - Tombol "Salin Laporan" untuk menyalin ringkasan ke clipboard.
  - Tombol "Selesai" untuk kembali ke langkah 1 (reset state wizard).
  - _Requirements: 6.3, 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 12. Buat screen utama wizard dan daftarkan routing
  - Buat file `lib/features/import_sheets/presentation/import_sheets_screen.dart` sebagai container wizard yang menampilkan step 1–5 berdasarkan `currentStep` dari provider.
  - Tambahkan `GoRoute` baru di `lib/core/router/app_router.dart` dalam `ShellRoute` admin:
    ```dart
    GoRoute(
      path: '/admin/import-sheets',
      builder: (context, state) => const ImportSheetsScreen(),
    ),
    ```
  - Tambahkan menu/tombol navigasi ke `/admin/import-sheets` di `AdminScaffold` atau `AdminDashboardScreen`.
  - _Requirements: 8.1, 8.2_

- [x] 13. Checkpoint — Pastikan semua tests lulus dan fitur dapat dijalankan end-to-end
  - Pastikan semua tests lulus, tanyakan kepada user jika ada pertanyaan.

- [ ] 14. Tulis property test untuk otorisasi akses fitur impor
  - **Property 11: Otorisasi Akses Fitur Impor**
  - Tulis widget test yang memverifikasi bahwa pengguna dengan role `pegawai` diarahkan ke halaman yang sesuai saat mencoba mengakses `/admin/import-sheets`.
  - **Validates: Requirements 8.1, 8.2**

- [ ] 15. Tulis property test untuk konsistensi statistik hasil impor
  - **Property 10: Konsistensi Statistik Hasil Impor**
  - Gunakan `fast_check`: generate `successCount` dan `failedCount` acak, verifikasi `successCount + failedCount == totalProcessed` pada `ImportResultModel`.
  - **Validates: Requirements 7.2**

- [ ] 16. Tulis property test untuk batas percobaan ulang
  - **Property 13: Batas Percobaan Ulang**
  - Gunakan `fast_check` dengan mock yang selalu gagal, verifikasi `withRetry` melakukan percobaan ulang tepat 3 kali dan tidak lebih.
  - **Validates: Requirements 9.5**

- [x] 17. Checkpoint akhir — Verifikasi integrasi lengkap
  - Pastikan semua tests lulus, tanyakan kepada user jika ada pertanyaan.

---

## Catatan

- Tasks bertanda `*` bersifat opsional dan dapat dilewati untuk MVP yang lebih cepat.
- Setiap task mereferensikan requirements spesifik untuk keterlacakan.
- Kolom `image_url` pada tabel `laporan` dan `dokumentasi` diisi langsung dari URL/link Drive yang sudah ada di spreadsheet — tidak perlu upload ulang ke Google Drive.
- Jalankan `dart run build_runner build --delete-conflicting-outputs` setelah membuat atau mengubah file provider Riverpod.
- Property tests menggunakan library `fast_check` (pub.dev) dengan minimum 100 iterasi per test.
- Edge Function `import-from-sheets` perlu di-deploy dengan `supabase functions deploy import-from-sheets`.
