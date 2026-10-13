/// Konfigurasi API dibaca dari environment variables saat build.
/// Set via --dart-define (lihat build.sh / run_local.sh) atau Vercel
/// Environment Variables.
class ApiConstants {
  ApiConstants._();

  static const String _apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );

  /// URL dasar API PantauPegawai di VPS, mis. `https://api.domain.go.id`.
  static String get apiUrl => _apiUrl.endsWith('/')
      ? _apiUrl.substring(0, _apiUrl.length - 1)
      : _apiUrl;

  /// URL proxy gambar Google Drive (publik, tanpa header Authorization).
  static String imageUrl(String fileId) => '$apiUrl/api/images?id=$fileId';

  /// Thumbnail kecil (±320 px) dari foto Drive, untuk daftar. Foto asli
  /// ([imageUrl]) baru dimuat saat foto dibuka.
  static String thumbnailUrl(String fileId) =>
      '$apiUrl/api/images/thumb?id=$fileId';

  /// API Key Google Sheets (untuk menu Import Data).
  static const String googleSheetsApiKey = String.fromEnvironment(
    'GOOGLE_SHEETS_API_KEY',
    defaultValue: '',
  );
}
