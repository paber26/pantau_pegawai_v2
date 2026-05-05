/// Utility untuk menangani berbagai format URL gambar Google Drive.
///
/// Data lama menyimpan URL dalam format:
///   https://drive.google.com/file/d/{FILE_ID}/view?usp=drivesdk
///
/// Data baru dari upload menyimpan URL dalam format image-proxy:
///   https://{supabase}.supabase.co/functions/v1/image-proxy?id={FILE_ID}
///
/// Fungsi ini mengkonversi URL Drive lama ke format direct link yang bisa
/// ditampilkan langsung oleh Image.network.
class ImageUrlUtils {
  ImageUrlUtils._();

  /// Konversi URL Google Drive ke URL yang bisa ditampilkan sebagai gambar.
  ///
  /// - image-proxy URL → return as-is (butuh auth header)
  /// - drive.google.com/file/d/{ID}/view → uc?export=view&id={ID}
  /// - drive.google.com/open?id={ID} → uc?export=view&id={ID}
  /// - lh3.googleusercontent.com → return as-is
  /// - uc?export=view → return as-is
  static String? toDisplayUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Sudah berupa image-proxy atau direct link → tidak perlu konversi
    if (url.contains('image-proxy') ||
        url.contains('lh3.googleusercontent.com') ||
        url.contains('uc?export=view') ||
        url.contains('uc%3Fexport%3Dview')) {
      return url;
    }

    // Format: https://drive.google.com/file/d/{FILE_ID}/view...
    final fileIdFromFile = RegExp(
      r'drive\.google\.com/file/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(url);
    if (fileIdFromFile != null) {
      final fileId = fileIdFromFile.group(1)!;
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }

    // Format: https://drive.google.com/open?id={FILE_ID}
    final fileIdFromOpen = RegExp(
      r'drive\.google\.com/open\?id=([a-zA-Z0-9_-]+)',
    ).firstMatch(url);
    if (fileIdFromOpen != null) {
      final fileId = fileIdFromOpen.group(1)!;
      return 'https://drive.google.com/uc?export=view&id=$fileId';
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

    // Format lh3.googleusercontent.com/d/{FILE_ID}
    final lh3Match = RegExp(
      r'lh3\.googleusercontent\.com/d/([a-zA-Z0-9_-]+)',
    ).firstMatch(url);
    if (lh3Match != null) return lh3Match.group(1);

    return null;
  }
}
