import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/utils/image_url_utils.dart';

/// Provider untuk fetch image bytes via image-proxy dengan Authorization header.
///
/// Selalu pakai anon key (bukan user access token) karena:
///   - User access token Supabase expire setiap 1 jam → di Android session
///     yang sudah expired bikin gambar putih permanen.
///   - Anon key tidak pernah expire dan cukup untuk lewat Supabase gateway.
///   - Edge function `image-proxy` tidak butuh user identity — function pakai
///     Service Account internal untuk akses Drive.
final _imageProvider =
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
/// Strategi cross-platform sama: fetch byte manual lewat [http.get] dengan
/// `Authorization: Bearer ${anonKey}`, lalu render via [Image.memory].
/// Pendekatan ini menghindari masalah:
///   - Token expired di Android ([Image.network] memakai header sekali saat
///     load awal dan tidak refresh saat token user expired).
///   - CORS preflight di web (browser kirim OPTIONS yang ditolak Supabase
///     bila tidak ada Authorization header).
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

    final imageAsync = ref.watch(_imageProvider(fileId));

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
