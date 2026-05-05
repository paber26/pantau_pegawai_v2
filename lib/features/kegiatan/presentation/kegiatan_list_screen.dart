import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/admin_scaffold.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../laporan/presentation/laporan_provider.dart';
import '../domain/kegiatan_model.dart';
import 'kegiatan_provider.dart';

class KegiatanListScreen extends ConsumerWidget {
  final bool isAdmin;

  const KegiatanListScreen({super.key, required this.isAdmin});

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Proyek'),
        content: const Text(
          'Masukkan 65 proyek ke database? Proyek yang sudah ada akan dilewati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // Tampilkan loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Mengimport proyek...'),
          ],
        ),
        duration: Duration(seconds: 30),
      ),
    );

    final result =
        await ref.read(kegiatanNotifierProvider.notifier).bulkImport();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil! ${result.inserted} proyek diimport, ${result.skipped} dilewati.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal melakukan import proyek.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kegiatanAsync = isAdmin
        ? ref.watch(kegiatanNotifierProvider)
        : ref.watch(myKegiatanProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isAdmin ? AppStrings.kegiatan : 'Tugas Saya'),
        leading: isAdmin ? const AdminMenuButton() : null,
        actions: [
          if (isAdmin) const AdminLogoutButton(),
          if (isAdmin)
            IconButton(
              tooltip: 'Import Proyek',
              icon: const Icon(Icons.upload_outlined),
              onPressed: () => _showImportDialog(context, ref),
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  ref.read(kegiatanNotifierProvider.notifier).refresh(),
            ),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/admin/kegiatan/tambah'),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kegiatan'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: kegiatanAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(
          message: e.toString(),
          onRetry: isAdmin
              ? () => ref.read(kegiatanNotifierProvider.notifier).refresh()
              : null,
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.assignment_outlined,
                      size: 64, color: AppColors.textHint),
                  const SizedBox(height: 16),
                  const Text(
                    'Belum ada kegiatan',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (!isAdmin) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Hubungi admin untuk mendapatkan penugasan',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              if (isAdmin) {
                ref.read(kegiatanNotifierProvider.notifier).refresh();
              } else {
                ref.invalidate(myKegiatanProvider);
              }
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _KegiatanCard(
                kegiatan: list[index],
                isAdmin: isAdmin,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KegiatanCard extends ConsumerWidget {
  final KegiatanModel kegiatan;
  final bool isAdmin;

  const _KegiatanCard({required this.kegiatan, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPassed = kegiatan.isDeadlinePassed;
    final daysLeft = kegiatan.deadline.difference(DateTime.now()).inDays;

    // Untuk pegawai: cek apakah sudah upload laporan untuk kegiatan ini
    final myLaporanAsync = isAdmin ? null : ref.watch(myLaporanProvider);
    final sudahUpload =
        myLaporanAsync?.valueOrNull?.any((l) => l.kegiatanId == kegiatan.id) ??
            false;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (isAdmin) {
            context.push('/admin/kegiatan/${kegiatan.id}/edit');
          } else {
            context.push('/pegawai/kegiatan/${kegiatan.id}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon kegiatan
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPassed
                          ? AppColors.error.withValues(alpha: 0.1)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.assignment_outlined,
                      color: isPassed ? AppColors.error : AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kegiatan.judul,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (kegiatan.deskripsi != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            kegiatan.deskripsi!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isAdmin)
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          context.push('/admin/kegiatan/${kegiatan.id}/edit');
                        } else if (value == 'assign') {
                          context.push('/admin/kegiatan/${kegiatan.id}/assign');
                        } else if (value == 'hapus') {
                          final confirm = await showConfirmDialog(
                            context,
                            title: AppStrings.konfirmasiHapus,
                            message: 'Hapus kegiatan "${kegiatan.judul}"?',
                          );
                          if (confirm == true && context.mounted) {
                            await ref
                                .read(kegiatanNotifierProvider.notifier)
                                .delete(kegiatan.id);
                          }
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                            value: 'assign', child: Text('Assign Pegawai')),
                        const PopupMenuItem(
                          value: 'hapus',
                          child: Text('Hapus',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Deadline
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: isPassed ? AppColors.error : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AppDateUtils.formatDate(kegiatan.deadline),
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          isPassed ? AppColors.error : AppColors.textSecondary,
                      fontWeight:
                          isPassed ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  // Status badge
                  if (!isAdmin)
                    _StatusBadge(sudahUpload: sudahUpload)
                  else
                    _DeadlineBadge(isPassed: isPassed, daysLeft: daysLeft),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool sudahUpload;

  const _StatusBadge({required this.sudahUpload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: sudahUpload
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: sudahUpload
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sudahUpload ? Icons.check_circle_outline : Icons.pending_outlined,
            size: 12,
            color: sudahUpload ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 4),
          Text(
            sudahUpload ? 'Sudah Upload' : 'Belum Upload',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: sudahUpload ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineBadge extends StatelessWidget {
  final bool isPassed;
  final int daysLeft;

  const _DeadlineBadge({required this.isPassed, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    if (isPassed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Lewat deadline',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.error,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: daysLeft <= 3
            ? AppColors.warning.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        daysLeft == 0 ? 'Hari ini' : '$daysLeft hari lagi',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: daysLeft <= 3 ? AppColors.warning : AppColors.success,
        ),
      ),
    );
  }
}
