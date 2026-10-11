import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/drive_image.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/photo_viewer.dart';
import '../domain/dokumentasi_model.dart';
import 'dokumentasi_provider.dart';

/// Daftar dokumentasi yang dihapus pegawai/admin (khusus admin).
///
/// Hapus di aplikasi hanya menyembunyikan dokumentasi; dari sini admin bisa
/// melihat siapa yang menghapus dan kapan, lalu mengembalikannya.
class DeletedDokumentasiScreen extends ConsumerWidget {
  const DeletedDokumentasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(deletedDokumentasiNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dokumentasi Dihapus'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(deletedDokumentasiNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: docsAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tidak ada dokumentasi yang dihapus.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(deletedDokumentasiNotifierProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, index) => _DeletedCard(doc: list[index]),
            ),
          );
        },
      ),
    );
  }
}

class _DeletedCard extends ConsumerWidget {
  final DokumentasiModel doc;

  const _DeletedCard({required this.doc});

  Future<void> _kembalikan(BuildContext context, WidgetRef ref) async {
    final confirm = await showConfirmDialog(
      context,
      title: 'Kembalikan Dokumentasi',
      message:
          'Kembalikan dokumentasi "${doc.proyek}" milik ${doc.pegawaiNama ?? 'pegawai'}? '
          'Dokumentasi akan tampil lagi di daftar.',
      confirmLabel: 'Kembalikan',
      destructive: false,
    );
    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(deletedDokumentasiNotifierProvider.notifier)
        .kembalikan(doc.id);
    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Dokumentasi dikembalikan'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedAt = doc.deletedAt?.toLocal();
    final deletedInfo = [
      if (doc.deletedByNama != null) 'Dihapus oleh ${doc.deletedByNama}',
      if (deletedAt != null) AppDateUtils.formatDateTime(deletedAt),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: doc.imageUrl != null
                  ? () => showPhotoViewer(context, doc.imageUrl!)
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DriveImage(
                  imageUrl: doc.imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (doc.pegawaiNama != null)
                    Text(doc.pegawaiNama!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(doc.proyek,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  Text(
                    'Kegiatan: ${AppDateUtils.formatDate(doc.tanggalKegiatan)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint),
                  ),
                  if (doc.catatan != null)
                    Text(doc.catatan!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint)),
                  if (deletedInfo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.delete_outline,
                          size: 12, color: AppColors.error),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(deletedInfo,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.error)),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _kembalikan(context, ref),
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Kembalikan'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
