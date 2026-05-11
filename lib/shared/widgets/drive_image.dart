import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/utils/image_url_utils.dart';

/// Widget untuk menampilkan gambar dari Google Drive via image-proxy Supabase.
///
/// Semua gambar diakses melalui image-proxy yang berjalan di server Supabase,
/// sehingga tidak ada masalah CORS di Flutter Web.
/// Proxy menggunakan service account Google — bisa akses semua file di Drive.
/// Auth tidak wajib di proxy (versi terbaru).
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

    // Ekstrak file ID dari URL apapun
    final fileId = ImageUrlUtils.extractFileId(imageUrl);
    if (fileId == null) return _placeholder();

    // Semua gambar via image-proxy — tidak ada CORS issue, tidak butuh auth header
    final proxyUrl = '${SupabaseConstants.imageProxyUrl}?id=$fileId';

    return CachedNetworkImage(
      imageUrl: proxyUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => Container(
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
