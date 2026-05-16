import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/utils/image_url_utils.dart';

/// Provider untuk fetch image bytes via image-proxy dengan Authorization header
/// (khusus web — browser tidak mengizinkan custom HTTP headers pada
/// Image.network karena pakai HTML <img>).
///
/// Selalu pakai anon key (bukan user access token) karena:
///   - User access token Supabase expire setiap 1 jam → di Android session
///     yang sudah expired bikin gambar putih permanen.
///   - Anon key tidak pernah expire dan cukup untuk lewat Supabase gateway.
///   - Edge function `image-proxy` tidak butuh user identity — function pakai
///     Service Account internal untuk akses Drive.
///
/// Cache: di web cukup mengandalkan HTTP cache browser (Cache-Control header
/// di response dari image-proxy = `public, max-age=86400`). Di mobile,
/// caching dilakukan oleh [CachedNetworkImage] (disk cache).
final _webImageProvider =
    FutureProvider.family<Uint8List?, String>((ref, fileId) async {
  final proxyUrl = Uri.parse('${SupabaseConstants.imageProxyUrl}?id=$fileId');

  final response = await http.get(
    proxyUrl,
    headers: {'Authorization': 'Bearer ${SupabaseConstants.anonKey}'},
  );

  if (response.statusCode == 200) {
    return response.bodyBytes;
  }
  return null;
});

/// Widget untuk menampilkan gambar dari Google Drive via image-proxy Supabase.
///
/// Strategi cross-platform:
///   - Mobile (Android/iOS): [CachedNetworkImage] — disk cache otomatis,
///     gambar yang sudah pernah didownload tidak diulang. `httpHeaders`
///     menyertakan Authorization Bearer dengan anon key.
///   - Web: fetch byte manual via [http.get] lalu render via [Image.memory].
///     Header tidak bisa di-pass ke `Image.network` di web (browser pakai
///     <img> tag), jadi pendekatan manual diperlukan. Cache mengandalkan
///     HTTP cache browser via `Cache-Control` dari image-proxy.
///
/// `cacheKey` di mobile dipatok ke `fileId` saja sehingga cache tidak
/// invalid hanya karena URL query berubah.
class DriveImage extends ConsumerWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const DriveImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _placeholder();
    }

    final fileId = ImageUrlUtils.extractFileId(imageUrl);
    if (fileId == null) return _placeholder();

    if (kIsWeb) {
      return _WebDriveImage(
        fileId: fileId,
        width: width,
        height: height,
        fit: fit,
      );
    }

    // Mobile: pakai CachedNetworkImage untuk disk cache.
    final proxyUrl = '${SupabaseConstants.imageProxyUrl}?id=$fileId';
    return CachedNetworkImage(
      imageUrl: proxyUrl,
      cacheKey: fileId,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: const {
        'Authorization': 'Bearer ${SupabaseConstants.anonKey}',
      },
      placeholder: (context, _) => Container(
        width: width,
        height: height,
        color: AppColors.background,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.background,
      child: const Icon(Icons.image_outlined, color: AppColors.textHint),
    );
  }
}

/// Widget khusus web yang fetch image bytes secara manual dengan auth header.
///
/// Cache di web bersifat implisit lewat HTTP cache browser; FutureProvider
/// tidak punya disk cache, jadi rebuild widget dengan fileId sama dalam
/// session yang sama akan mengambil dari memori provider, sementara
/// reload halaman akan memanfaatkan HTTP cache browser sesuai
/// `Cache-Control: public, max-age=86400` yang dikirim image-proxy.
class _WebDriveImage extends ConsumerWidget {
  final String fileId;
  final double? width;
  final double? height;
  final BoxFit fit;

  const _WebDriveImage({
    required this.fileId,
    this.width,
    this.height,
    required this.fit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageAsync = ref.watch(_webImageProvider(fileId));

    return imageAsync.when(
      loading: () => Container(
        width: width,
        height: height,
        color: AppColors.background,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => _placeholder(),
      data: (bytes) {
        if (bytes == null) return _placeholder();
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stack) => _placeholder(),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.background,
      child: const Icon(Icons.image_outlined, color: AppColors.textHint),
    );
  }
}
