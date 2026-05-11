import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/admin_scaffold.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../domain/kegiatan_model.dart';
import 'kegiatan_provider.dart';

class KegiatanListScreen extends ConsumerWidget {
  final bool isAdmin;

  const KegiatanListScreen({super.key, required this.isAdmin});

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: AppColors.primary,
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
        ),
      ),
    );
  }
}
