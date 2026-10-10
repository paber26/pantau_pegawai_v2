/// Utility untuk menangani berbagai format URL gambar Google Drive.
///
/// Format URL yang tersimpan di database:
///   - Data lama AppSheet: https://drive.google.com/file/d/{FILE_ID}/view?usp=drivesdk
///   - Upload via Supabase (sebelum pindah ke VPS):
///     https://{project}.supabase.co/functions/v1/image-proxy?id={FILE_ID}
///   - Upload via API VPS: https://{api}/api/images?id={FILE_ID}
///
/// Semuanya diubah ke file ID lalu ditampilkan lewat proxy gambar API
/// (lihat `DriveImage`).
class ImageUrlUtils {
  ImageUrlUtils._();

  /// Ekstrak Google Drive file ID dari berbagai format URL.
  static String? extractFileId(String? url) {
    if (url == null || url.isEmpty) return null;

    // Format proxy gambar (API VPS / Supabase lama): ?id={FILE_ID}
    final proxyMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (proxyMatch != null) return proxyMatch.group(1);

    // Format file/d/{FILE_ID}
    final fileMatch = RegExp(
      r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(url);
    if (fileMatch != null) return fileMatch.group(1);

    // Format lh3.googleusercontent.com/d/{FILE_ID}
    final lh3Match = RegExp(
      r'lh3\.googleusercontent\.com/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(url);
    if (lh3Match != null) return lh3Match.group(1);

    return null;
  }
}
