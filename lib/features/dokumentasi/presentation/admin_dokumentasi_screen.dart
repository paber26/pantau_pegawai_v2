import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/image_url_utils.dart';
import '../../../shared/widgets/admin_scaffold.dart';
import '../../../shared/widgets/drive_image.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../domain/dokumentasi_model.dart';
import 'dokumentasi_provider.dart';

class AdminDokumentasiScreen extends ConsumerWidget {
  const AdminDokumentasiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(adminDokumentasiNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dokumentasi Harian'),
        leading: const AdminMenuButton(),
        actions: [
          const AdminLogoutButton(),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(adminDokumentasiNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      body: docsAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('Belum ada dokumentasi',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          // Kelompokkan per tanggal
          final grouped = <DateTime, List<DokumentasiModel>>{};
          for (final doc in list) {
            final date = DateTime(doc.tanggalKegiatan.year,
                doc.tanggalKegiatan.month, doc.tanggalKegiatan.day);
            grouped.putIfAbsent(date, () => []).add(doc);
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(adminDokumentasiNotifierProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped.entries.elementAt(index);
                return _AdminDateGroup(tanggal: entry.key, items: entry.value);
              },
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    DateTime? fromDate;
    DateTime? toDate;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Filter Tanggal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Dari Tanggal'),
                subtitle: Text(fromDate != null
                    ? AppDateUtils.formatDate(fromDate!)
                    : 'Pilih tanggal'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => fromDate = picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Sampai Tanggal'),
                subtitle: Text(toDate != null
                    ? AppDateUtils.formatDate(toDate!)
                    : 'Pilih tanggal'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => toDate = picked);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref
                            .read(adminDokumentasiNotifierProvider.notifier)
                            .applyFilter();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref
                            .read(adminDokumentasiNotifierProvider.notifier)
                            .applyFilter(fromDate: fromDate, toDate: toDate);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Terapkan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDateGroup extends StatelessWidget {
  final DateTime tanggal;
  final List<DokumentasiModel> items;

  const _AdminDateGroup({required this.tanggal, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('d MMMM yyyy', 'id_ID').format(tanggal),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                  child: Divider(color: AppColors.divider, height: 1)),
              const SizedBox(width: 8),
              Text('${items.length} entri',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
        ),
        ...items.map((doc) => _AdminDokCard(doc: doc)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AdminDokCard extends StatelessWidget {
  final DokumentasiModel doc;

  const _AdminDokCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Foto
            GestureDetector(
              onTap: doc.imageUrl != null
                  ? () => _showFullImage(
                      context, ImageUrlUtils.toDisplayUrl(doc.imageUrl)!)
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
                  // Nama pegawai
                  if (doc.pegawaiNama != null)
                    Text(doc.pegawaiNama!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(doc.proyek,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  if (doc.catatan != null)
                    Text(doc.catatan!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textHint)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 11, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text(
                        DateFormat('HH:mm').format(doc.createdAt.toLocal()),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                      ),
                      if (doc.link != null || doc.imageUrl != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final rawUrl = doc.link ?? doc.imageUrl ?? '';
                            final fileId = ImageUrlUtils.extractFileId(rawUrl);
                            final driveUrl = fileId != null
                                ? 'https://drive.google.com/file/d/$fileId/view'
                                : rawUrl;
                            await Clipboard.setData(
                                ClipboardData(text: driveUrl));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Link berhasil disalin!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          child: const Row(children: [
                            Icon(Icons.copy_outlined,
                                size: 11, color: AppColors.primary),
                            SizedBox(width: 2),
                            Text('Copy Link',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.primary)),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
