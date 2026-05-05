/// Utility untuk menangani berbagai format URL gambar Google Drive.
///
/// Data lama dari migrasi AppSheet menyimpan URL dalam format:
///   https://drive.google.com/file/d/{FILE_ID}/view?usp=drivesdk
///
/// Data baru dari upload menyimpan URL dalam format image-proxy:
///   https://{supabase}.supabase.co/functions/v1/image-proxy?id={FILE_ID}
///
/// Fungsi ini mengkonversi URL Drive lama ke format thumbnail yang bisa
/// ditampilkan langsung di browser tanpa CORS issue.
class ImageUrlUtils {
  ImageUrlUtils._();

  /// Konversi URL Google Drive ke URL yang bisa ditampilkan sebagai gambar.
  ///
  /// - Jika sudah berupa image-proxy URL → return as-is
  /// - Jika berupa Google Drive view URL → ekstrak file ID dan buat thumbnail URL
  /// - Jika format lain → return as-is
  static String? toDisplayUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Sudah berupa image-proxy atau URL gambar langsung → tidak perlu konversi
    if (url.contains('image-proxy') ||
        url.contains('lh3.googleusercontent.com') ||
        url.contains('uc?export=view')) {
      return url;
    }

    // Format: https://drive.google.com/file/d/{FILE_ID}/view...
    final fileIdMatch = RegExp(
      r'https://drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(url);

    if (fileIdMatch != null) {
      final fileId = fileIdMatch.group(1)!;
      // Gunakan thumbnail endpoint Google Drive yang bisa diakses publik
      // size=s800 = max 800px, cocok untuk preview
      return 'https://lh3.googleusercontent.com/d/$fileId=s800';
    }

    // Format: https://drive.google.com/open?id={FILE_ID}
    final openIdMatch = RegExp(
      r'https://drive\.google\.com/open\?id=([a-zA-Z0-9_-]+)',
    ).firstMatch(url);

    if (openIdMatch != null) {
      final fileId = openIdMatch.group(1)!;
      return 'https://lh3.googleusercontent.com/d/$fileId=s800';
    }

    return url;
  }

  /// Ekstrak Google Drive file ID dari berbagai format URL.
  static String? extractFileId(String? url) {
    if (url == null || url.isEmpty) return null;

    // Format image-proxy: ?id={FILE_ID}
    final proxyMatch = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)').firstMatch(url);
    if (proxyMatch != null) return proxyMatch.group(1);

    // Format file/d/{FILE_ID}
    final fileMatch = RegExp(
      r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(url);
    if (fileMatch != null) return fileMatch.group(1);

    return null;
  }
}
