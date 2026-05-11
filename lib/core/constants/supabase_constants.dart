/// Konfigurasi Supabase dibaca dari environment variables saat build.
/// Set via --dart-define atau Vercel Environment Variables.
class SupabaseConstants {
  SupabaseConstants._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// URL Edge Function untuk upload ke Google Drive
  static const String uploadDriveFunctionUrl =
      '$url/functions/v1/upload-to-drive';

  /// URL Edge Function proxy untuk menampilkan gambar dari Google Drive
  static const String imageProxyUrl = '$url/functions/v1/image-proxy';

  /// URL Edge Function untuk import data dari Google Sheets
  static const String importSheetsFunctionUrl =
      '$url/functions/v1/import-from-sheets';

  /// URL Edge Function untuk reset password oleh admin
  static const String adminResetPasswordUrl =
      '$url/functions/v1/admin-reset-password';

  /// API Key Google Sheets
  static const String googleSheetsApiKey = String.fromEnvironment(
    'GOOGLE_SHEETS_API_KEY',
    defaultValue: '',
  );
}
