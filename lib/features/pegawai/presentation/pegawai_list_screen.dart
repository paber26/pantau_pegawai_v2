import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../domain/pegawai_model.dart';
import 'pegawai_provider.dart';

class PegawaiListScreen extends ConsumerWidget {
  const PegawaiListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pegawaiAsync = ref.watch(pegawaiNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.pegawai),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(pegawaiNotifierProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/pegawai/tambah'),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.tambahPegawai),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: pegawaiAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(
          message: e.toString(),
          onRetry: () => ref.read(pegawaiNotifierProvider.notifier).refresh(),
        ),
        data: (list) => list.isEmpty
            ? const Center(child: Text(AppStrings.tidakAdaData))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) =>
                    _PegawaiCard(pegawai: list[index]),
              ),
      ),
    );
  }
}

class _PegawaiCard extends ConsumerWidget {
  final PegawaiModel pegawai;

  const _PegawaiCard({required this.pegawai});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            pegawai.nama.isNotEmpty ? pegawai.nama[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          pegawai.nama,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pegawai.email, style: const TextStyle(fontSize: 12)),
            if (pegawai.jabatan != null)
              Text(
                '${pegawai.jabatan} • ${pegawai.unitKerja ?? '-'}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleBadge(role: pegawai.role),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  context.push('/admin/pegawai/${pegawai.id}/edit');
                } else if (value == 'hapus') {
                  final confirm = await showConfirmDialog(
                    context,
                    title: AppStrings.konfirmasiHapus,
                    message: 'Hapus pegawai ${pegawai.nama}?',
                  );
                  if (confirm == true && context.mounted) {
                    final errorMsg = await ref
                        .read(pegawaiNotifierProvider.notifier)
                        .delete(pegawai.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg == null
                              ? 'Pegawai dihapus'
                              : 'Gagal: $errorMsg'),
                          backgroundColor: errorMsg == null
                              ? AppColors.success
                              : AppColors.error,
                          duration: const Duration(seconds: 6),
                        ),
                      );
                    }
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text(AppStrings.edit)),
                const PopupMenuItem(
                  value: 'hapus',
                  child: Text(AppStrings.hapus,
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: pegawai.jabatan != null,
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAdmin ? 'Admin' : 'Pegawai',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isAdmin ? AppColors.primary : AppColors.accent,
        ),
      ),
    );
  }
}
