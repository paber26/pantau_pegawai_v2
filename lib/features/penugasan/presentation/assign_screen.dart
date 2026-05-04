import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../pegawai/presentation/pegawai_provider.dart';
import 'penugasan_provider.dart';

class AssignScreen extends ConsumerWidget {
  final String kegiatanId;

  const AssignScreen({super.key, required this.kegiatanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pegawaiAsync = ref.watch(pegawaiNotifierProvider);
    final penugasanAsync = ref.watch(penugasanNotifierProvider(kegiatanId));

    return Scaffold(
      appBar: AppBar(title: const Text('Assign Pegawai')),
      body: pegawaiAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(message: e.toString()),
        data: (allPegawai) => penugasanAsync.when(
          loading: () => const LoadingShimmer(),
          error: (e, _) => ErrorDisplay(message: e.toString()),
          data: (penugasanList) {
            final assignedIds =
                penugasanList.map((p) => p.userId).toSet();

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: allPegawai.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final pegawai = allPegawai[index];
                final isAssigned = assignedIds.contains(pegawai.id);

                return Card(
                  child: CheckboxListTile(
                    value: isAssigned,
                    onChanged: (checked) async {
                      if (checked == true) {
                        await ref
                            .read(penugasanNotifierProvider(kegiatanId).notifier)
                            .assign(
                              userId: pegawai.id,
                              kegiatanId: kegiatanId,
                            );
                      } else {
                        await ref
                            .read(penugasanNotifierProvider(kegiatanId).notifier)
                            .unassign(
                              userId: pegawai.id,
                              kegiatanId: kegiatanId,
                            );
                      }
                    },
                    title: Text(
                      pegawai.nama,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${pegawai.jabatan ?? '-'} • ${pegawai.unitKerja ?? '-'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: isAssigned
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      child: Text(
                        pegawai.nama.isNotEmpty
                            ? pegawai.nama[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: isAssigned
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
