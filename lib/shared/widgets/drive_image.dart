import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/image_url_utils.dart';

/// Widget untuk menampilkan gambar Google Drive lewat proxy gambar API
/// (`GET /api/images?id=<fileId>`).
///
/// Proxy gambar tidak butuh login, jadi gambar tetap tampil walau sesi
/// habis dan bisa dimuat langsung oleh browser di web. Semua format URL
/// yang tersimpan (URL proxy Supabase lama, URL proxy API baru, URL Drive
/// lama dari AppSheet) diubah ke file ID lalu diarahkan ke proxy API.
///
/// Cache: di mobile, [CachedNetworkImage] menyimpan ke disk dengan
/// `cacheKey = fileId` sehingga cache tidak hilang hanya karena domain URL
/// berubah. Di web, browser memakai HTTP cache (`Cache-Control` dari API).
class DriveImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Muat thumbnail kecil, bukan foto asli. Untuk gambar kecil di daftar,
  /// agar halaman cepat tampil dan hemat kuota.
  final bool thumbnail;

  const DriveImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.thumbnail = false,
  });

  /// URL dan cache key untuk file Drive [fileId].
  static ({String url, String cacheKey}) source(String fileId,
          {required bool thumbnail}) =>
      thumbnail
          ? (url: ApiConstants.thumbnailUrl(fileId), cacheKey: '$fileId@thumb')
          : (url: ApiConstants.imageUrl(fileId), cacheKey: fileId);

  @override
  Widget build(BuildContext context) {
    final fileId = ImageUrlUtils.extractFileId(imageUrl);
    if (fileId == null) return _placeholder();
    final src = source(fileId, thumbnail: thumbnail);

    return CachedNetworkImage(
      imageUrl: src.url,
      cacheKey: src.cacheKey,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, _) => Container(
        width: width,
        height: height,
        color: AppColors.background,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      // Thumbnail gagal (mis. API belum versi baru): pakai foto asli.
      errorWidget: (context, url, error) => thumbnail
          ? DriveImage(
              imageUrl: imageUrl, width: width, height: height, fit: fit)
          : _placeholder(),
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
