import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../domain/laporan_model.dart';
import 'laporan_provider.dart';

class LaporanListScreen extends ConsumerWidget {
  final bool isAdmin;

  const LaporanListScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laporanAsync = isAdmin
        ? ref.watch(adminLaporanNotifierProvider)
        : ref.watch(myLaporanProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isAdmin ? AppStrings.laporan : 'Riwayat Laporan'),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterSheet(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(adminLaporanNotifierProvider.notifier).refresh(),
            ),
          ],
        ],
      ),
      body: laporanAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(message: e.toString()),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined,
                      size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  Text(
                    isAdmin
                        ? 'Belum ada laporan masuk'
                        : 'Belum ada laporan dikirim',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              if (isAdmin) {
                ref.read(adminLaporanNotifierProvider.notifier).refresh();
              } else {
                ref.invalidate(myLaporanProvider);
              }
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _LaporanCard(
                laporan: list[index],
                isAdmin: isAdmin,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FilterSheet(
        onApply: (fromDate, toDate) {
          ref.read(adminLaporanNotifierProvider.notifier).applyFilter(
                fromDate: fromDate,
                toDate: toDate,
              );
        },
      ),
    );
  }
}

class _LaporanCard extends StatelessWidget {
  final LaporanModel laporan;
  final bool isAdmin;

  const _LaporanCard({required this.laporan, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final route = isAdmin
        ? '/admin/laporan/${laporan.id}'
        : '/pegawai/riwayat/${laporan.id}';

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  laporan.imageUrl,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 72,
                      height: 72,
                      color: AppColors.background,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    color: AppColors.background,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textHint),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAdmin && laporan.pegawaiNama != null)
                      Text(
                        laporan.pegawaiNama!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    if (laporan.kegiatanJudul != null)
                      Text(
                        laporan.kegiatanJudul!,
                        style: TextStyle(
                          fontSize: isAdmin ? 12 : 14,
                          fontWeight:
                              isAdmin ? FontWeight.normal : FontWeight.w600,
                          color: isAdmin
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (laporan.deskripsi != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        laporan.deskripsi!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 11, color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Text(
                          AppDateUtils.formatDateTime(laporan.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final void Function(DateTime? fromDate, DateTime? toDate) onApply;

  const _FilterSheet({required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Filter Laporan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _DateTile(
            label: 'Dari Tanggal',
            date: _fromDate,
            onTap: () => _pickDate(true),
          ),
          const SizedBox(height: 8),
          _DateTile(
            label: 'Sampai Tanggal',
            date: _toDate,
            onTap: () => _pickDate(false),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onApply(null, null);
                    Navigator.pop(context);
                  },
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_fromDate, _toDate);
                    Navigator.pop(context);
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 12),
            Column(
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
                  date != null
                      ? AppDateUtils.formatDate(date!)
                      : 'Pilih tanggal',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: date != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
