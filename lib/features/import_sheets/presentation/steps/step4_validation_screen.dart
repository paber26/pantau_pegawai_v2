import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../import_sheets_provider.dart';

class Step4ValidationScreen extends ConsumerStatefulWidget {
  const Step4ValidationScreen({super.key});

  @override
  ConsumerState<Step4ValidationScreen> createState() =>
      _Step4ValidationScreenState();
}

class _Step4ValidationScreenState extends ConsumerState<Step4ValidationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(importSheetsNotifierProvider.notifier).runValidation();
    });
  }

  Future<void> _confirmAndImport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Impor'),
        content: Builder(builder: (context) {
          final state = ref.read(importSheetsNotifierProvider);
          final validRows = state.validationResult?.validRows ?? 0;
          return Text(
            'Anda akan mengimpor $validRows baris data ke tabel "${state.targetTable ?? '-'}".\n\nLanjutkan?',
          );
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mulai Impor'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(importSheetsNotifierProvider.notifier).startImport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importSheetsNotifierProvider);
    final notifier = ref.read(importSheetsNotifierProvider.notifier);
    final result = state.validationResult;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Validasi Data',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sistem memeriksa setiap baris data sebelum diimpor.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (result != null) ...[
                const SizedBox(height: 16),
                // Summary cards
                Row(
                  children: [
                    _SummaryCard(
                      label: 'Total Baris',
                      value: result.totalRows.toString(),
                      color: AppColors.primary,
                      icon: Icons.table_rows_outlined,
                    ),
                    const SizedBox(width: 12),
                    _SummaryCard(
                      label: 'Baris Valid',
                      value: result.validRows.toString(),
                      color: AppColors.success,
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 12),
                    _SummaryCard(
                      label: 'Baris Error',
                      value: result.invalidRows.toString(),
                      color: AppColors.error,
                      icon: Icons.error_outline,
                    ),
                  ],
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
              'Daftar Error (${result.errors.length})',
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${error.columnName}: "${error.value}"',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                error.message,
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
                );
              },
            ),
          ),
        ] else if (result != null && result.errors.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 56, color: AppColors.success),
                  SizedBox(height: 12),
                  Text(
                    'Semua baris valid!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          ),

        // Navigation buttons
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => notifier.goToStep(3),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali ke Pemetaan'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed:
                    (result != null && result.validRows > 0 && !state.isLoading)
                        ? _confirmAndImport
                        : null,
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Mulai Impor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
