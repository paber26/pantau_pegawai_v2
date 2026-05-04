import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/error_display.dart';
import '../../laporan/presentation/laporan_provider.dart';
import '../../laporan/domain/laporan_model.dart';
import '../../laporan/presentation/laporan_detail_screen.dart';
import 'kegiatan_provider.dart';

class KegiatanDetailScreen extends ConsumerWidget {
  final String kegiatanId;

  const KegiatanDetailScreen({super.key, required this.kegiatanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myLaporanAsync = ref.watch(myLaporanProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Detail Kegiatan')),
      body: FutureBuilder(
        future: ref.read(kegiatanRepositoryProvider).getById(kegiatanId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorDisplay(message: snapshot.error.toString());
          }
          final kegiatan = snapshot.data!;
          final isPassed = kegiatan.isDeadlinePassed;

          // Laporan untuk kegiatan ini
          final laporanKegiatan = myLaporanAsync.valueOrNull
                  ?.where((l) => l.kegiatanId == kegiatanId)
                  .toList() ??
              [];
          final sudahUpload = laporanKegiatan.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                kegiatan.judul,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isPassed
                                    ? AppColors.error.withValues(alpha: 0.1)
                                    : AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPassed ? 'Lewat Deadline' : 'Aktif',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: isPassed
                                      ? AppColors.error
                                      : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (kegiatan.deskripsi != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            kegiatan.deskripsi!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Deadline',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  AppDateUtils.formatDate(kegiatan.deadline),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isPassed
                                        ? AppColors.error
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Status upload
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: sudahUpload
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            sudahUpload
                                ? Icons.check_circle_outline
                                : Icons.upload_file_outlined,
                            color: sudahUpload
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sudahUpload
                                    ? 'Laporan Sudah Dikirim'
                                    : 'Belum Ada Laporan',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                sudahUpload
                                    ? '${laporanKegiatan.length} laporan dikirim'
                                    : 'Kirim laporan untuk kegiatan ini',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Tombol upload
                ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/pegawai/kegiatan/$kegiatanId/upload'),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                      sudahUpload ? 'Kirim Laporan Lagi' : 'Kirim Laporan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Riwayat laporan untuk kegiatan ini
                if (laporanKegiatan.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Laporan Terkirim',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...laporanKegiatan.map(
                    (laporan) => _LaporanMiniCard(laporan: laporan),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LaporanMiniCard extends StatelessWidget {
  final LaporanModel laporan;

  const _LaporanMiniCard({required this.laporan});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/pegawai/riwayat/${laporan.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  laporan.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: AppColors.background,
                    child: const Icon(Icons.image_outlined,
                        color: AppColors.textHint),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (laporan.deskripsi != null)
                      Text(
                        laporan.deskripsi!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    Text(
                      AppDateUtils.formatDateTime(laporan.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
