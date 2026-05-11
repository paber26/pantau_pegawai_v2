import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_constants.dart';
import '../../core/utils/image_url_utils.dart';

/// Provider untuk fetch image bytes via image-proxy dengan auth header.
/// Diperlukan di web karena CachedNetworkImage tidak support custom headers.
final _imageProvider =
    FutureProvider.family<Uint8List?, String>((ref, fileId) async {
  final proxyUrl = Uri.parse('${SupabaseConstants.imageProxyUrl}?id=$fileId');

  // Gunakan session token jika tersedia, fallback ke anon key
  final session = Supabase.instance.client.auth.currentSession;
  final token = session?.accessToken ?? SupabaseConstants.anonKey;

  final response = await http.get(
    proxyUrl,
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    return response.bodyBytes;
  }
  return null;
});

/// Widget untuk menampilkan gambar dari Google Drive via image-proxy Supabase.
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

    // Di web: fetch manual dengan auth header untuk menghindari CORS issue
    // Di mobile: gunakan Image.network langsung (lebih efisien)
    if (kIsWeb) {
      return _WebDriveImage(
        fileId: fileId,
        width: width,
        height: height,
        fit: fit,
      );
    }

    // Mobile: langsung pakai URL proxy tanpa header (tidak ada CORS issue)
    final proxyUrl = '${SupabaseConstants.imageProxyUrl}?id=$fileId';
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? SupabaseConstants.anonKey;

    return Image.network(
      proxyUrl,
      width: width,
      height: height,
      fit: fit,
      headers: {'Authorization': 'Bearer $token'},
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: AppColors.background,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      errorBuilder: (context, error, stack) => _placeholder(),
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

/// Widget khusus web yang fetch image bytes secara manual dengan auth header
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
