import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/admin_scaffold.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../domain/rekap_upload_model.dart';
import 'rekap_upload_provider.dart';

/// Nama bulan singkat dalam Bahasa Indonesia.
const _kNamaBulan = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

class RekapUploadScreen extends ConsumerWidget {
  const RekapUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rekapAsync = ref.watch(rekapUploadNotifierProvider);
    final notifier = ref.read(rekapUploadNotifierProvider.notifier);
    final selectedYear = notifier.selectedYear;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rekap Upload'),
        leading: const AdminMenuButton(),
        actions: [
          _YearDropdown(
            selectedYear: selectedYear,
            onChanged: (year) => notifier.changeYear(year),
          ),
          const AdminLogoutButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => notifier.refresh(),
          ),
        ],
      ),
      body: rekapAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorDisplay(
          message: e.toString(),
          onRetry: () => notifier.refresh(),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _EmptyRekap();
          }

          final grandTotal = list.fold<int>(0, (sum, r) => sum + r.total);

          return RefreshIndicator(
            onRefresh: () => notifier.refresh(),
            child: Column(
              children: [
                _GrandTotalBanner(year: selectedYear, grandTotal: grandTotal),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      return _RekapCard(
                        rekap: list[index],
                        rank: index + 1,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _YearDropdown
// ---------------------------------------------------------------------------

class _YearDropdown extends StatelessWidget {
  final int selectedYear;
  final ValueChanged<int> onChanged;

  const _YearDropdown({
    required this.selectedYear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    final years = List.generate(
      currentYear - 2024 + 1,
      (i) => 2024 + i,
    );

    return DropdownButton<int>(
      value: selectedYear,
      dropdownColor: AppColors.primary,
      underline: const SizedBox.shrink(),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
      items: years
          .map(
            (year) => DropdownMenuItem<int>(
              value: year,
              child: Text(
                year.toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(),
      onChanged: (year) {
        if (year != null) onChanged(year);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _GrandTotalBanner
// ---------------------------------------------------------------------------

class _GrandTotalBanner extends StatelessWidget {
  final int year;
  final int grandTotal;

  const _GrandTotalBanner({required this.year, required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Upload $year',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            grandTotal.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyRekap
// ---------------------------------------------------------------------------

class _EmptyRekap extends StatelessWidget {
  const _EmptyRekap();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 64,
            color: AppColors.textHint,
          ),
          SizedBox(height: 16),
          Text(
            'Belum ada data upload untuk tahun ini',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RekapCard
// ---------------------------------------------------------------------------

class _RekapCard extends StatelessWidget {
  final RekapUploadModel rekap;
  final int rank;

  const _RekapCard({required this.rekap, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris utama: rank | info pegawai | badge total
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nomor rank
                SizedBox(
                  width: 32,
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Info pegawai
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rekap.nama,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (rekap.jabatan != null && rekap.jabatan!.isNotEmpty)
                        Text(
                          rekap.jabatan!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (rekap.unitKerja != null &&
                          rekap.unitKerja!.isNotEmpty)
                        Text(
                          rekap.unitKerja!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                ),

                // Badge total
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    rekap.total.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Breakdown per bulan — horizontal scrollable
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(12, (i) {
                  final bulan = i + 1;
                  final count = rekap.perBulan[bulan] ?? 0;
                  final hasUpload = count > 0;

                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: hasUpload
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _kNamaBulan[i],
                          style: TextStyle(
                            fontSize: 10,
                            color: hasUpload
                                ? AppColors.primary
                                : AppColors.textHint,
                            fontWeight:
                                hasUpload ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: hasUpload
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
