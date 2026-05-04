import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/error_display.dart';
import 'laporan_provider.dart';

class LaporanDetailScreen extends ConsumerWidget {
  final String laporanId;

  const LaporanDetailScreen({super.key, required this.laporanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title:
            const Text('Detail Laporan', style: TextStyle(color: Colors.white)),
      ),
      body: FutureBuilder(
        future: ref.read(laporanRepositoryProvider).getById(laporanId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return ErrorDisplay(message: snapshot.error.toString());
          }
          final laporan = snapshot.data!;

          return Column(
            children: [
              // Foto fullscreen
              Expanded(
                child: InteractiveViewer(
                  child: Image.network(
                    laporan.imageUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 64, color: Colors.white54),
                    ),
                  ),
                ),
              ),

              // Info panel
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Info rows
                          if (laporan.pegawaiNama != null)
                            _InfoRow(
                              icon: Icons.person_outline,
                              label: 'Pegawai',
                              value: laporan.pegawaiNama!,
                            ),
                          if (laporan.kegiatanJudul != null) ...[
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.assignment_outlined,
                              label: 'Kegiatan',
                              value: laporan.kegiatanJudul!,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _InfoRow(
                            icon: Icons.access_time,
                            label: 'Waktu Upload',
                            value:
                                AppDateUtils.formatDateTime(laporan.createdAt),
                          ),

                          // Deskripsi
                          if (laporan.deskripsi != null) ...[
                            const SizedBox(height: 16),
                            const Divider(height: 1),
                            const SizedBox(height: 16),
                            const Text(
                              'Deskripsi',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              laporan.deskripsi!,
                              style: const TextStyle(
                                height: 1.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Buka di Google Drive
                          OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(laporan.imageUrl);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Buka di Google Drive'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
