import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/supabase_constants.dart';

/// Widget untuk menampilkan gambar dari Google Drive via proxy.
/// Otomatis menambahkan Authorization header dari session Supabase.
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

    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;

    // Kalau URL sudah pakai proxy Supabase, tambahkan auth header
    // Kalau URL lain (misal langsung Drive), tampilkan biasa
    final isProxyUrl = imageUrl!.contains(SupabaseConstants.url);

    if (!isProxyUrl || token == null) {
      // Fallback: coba load langsung
      return Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    return Image.network(
      imageUrl!,
      width: width,
      height: height,
      fit: fit,
      headers: {'Authorization': 'Bearer $token'},
      errorBuilder: (_, __, ___) => _placeholder(),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          color: AppColors.background,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
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
