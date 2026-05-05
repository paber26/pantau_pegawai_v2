import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../import_sheets_provider.dart';

class Step5ResultScreen extends ConsumerWidget {
  const Step5ResultScreen({super.key});

  String _formatDuration(Duration d) {
    if (d.inMinutes >= 1) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }

  String _buildReport(ImportWizardState state) {
    final result = state.importResult;
    if (result == null) return '';
    final buf = StringBuffer();
    buf.writeln('=== Laporan Impor Data ===');
    buf.writeln('Tabel tujuan : ${state.targetTable ?? '-'}');
    buf.writeln('Total diproses: ${result.totalProcessed}');
    buf.writeln('Berhasil      : ${result.successCount}');
    buf.writeln('Gagal         : ${result.failedCount}');
    buf.writeln('Durasi        : ${_formatDuration(result.duration)}');
    if (result.errors.isNotEmpty) {
      buf.writeln('\nDaftar Error:');
      for (final e in result.errors) {
        buf.writeln('  Baris ${e.rowIndex}: ${e.message}');
      }
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importSheetsNotifierProvider);
    final notifier = ref.read(importSheetsNotifierProvider.notifier);
    final result = state.importResult;

    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              child: LinearProgressIndicator(),
            ),
            SizedBox(height: 16),
            Text(
              'Mengimpor data...',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hasil Impor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Proses impor telah selesai. Berikut ringkasan hasilnya.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _StatRow(
                          icon: Icons.table_rows_outlined,
                          label: 'Total Diproses',
                          value: result.totalProcessed.toString(),
                          color: AppColors.primary,
                        ),
                        const Divider(height: 16),
                        _StatRow(
                          icon: Icons.check_circle_outline,
                          label: 'Berhasil',
                          value: result.successCount.toString(),
                          color: AppColors.success,
                        ),
                        const Divider(height: 16),
                        _StatRow(
                          icon: Icons.error_outline,
                          label: 'Gagal',
                          value: result.failedCount.toString(),
                          color: AppColors.error,
                        ),
                        const Divider(height: 16),
                        _StatRow(
                          icon: Icons.timer_outlined,
                          label: 'Durasi',
                          value: _formatDuration(result.duration),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Error list
        if (result != null && result.errors.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Baris Gagal (${result.errors.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: result.errors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final error = result.errors[index];
                return Card(
                  color: AppColors.error.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Baris ${error.rowIndex}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error.message,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ] else
          const Spacer(),

        // Action buttons
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (result != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    final report = _buildReport(state);
                    await Clipboard.setData(ClipboardData(text: report));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Laporan disalin ke clipboard.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Salin Laporan'),
                ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: notifier.reset,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Selesai'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
