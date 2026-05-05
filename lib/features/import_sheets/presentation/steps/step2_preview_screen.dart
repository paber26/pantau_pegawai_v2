import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/preview_utils.dart';
import '../import_sheets_provider.dart';

class Step2PreviewScreen extends ConsumerWidget {
  const Step2PreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importSheetsNotifierProvider);
    final notifier = ref.read(importSheetsNotifierProvider.notifier);

    final hasSelection = state.selectedSheet != null;
    final hasData = state.previewRows.isNotEmpty;
    final canProceed = hasSelection && hasData && !state.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih Sheet & Pratinjau Data',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih sheet yang ingin diimpor, lalu tinjau data sebelum melanjutkan.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              // Sheet chips
              if (state.sheetList.isEmpty)
                const Text(
                  'Tidak ada sheet tersedia.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.sheetList.map((sheet) {
                    final isSelected = state.selectedSheet == sheet.title;
                    return ChoiceChip(
                      label: Text(sheet.title),
                      selected: isSelected,
                      onSelected: state.isLoading
                          ? null
                          : (_) => notifier.selectSheet(sheet.title),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Loading indicator
        if (state.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hasSelection && !hasData)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.table_chart_outlined,
                      size: 48, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text(
                    'Sheet ini tidak memiliki data untuk diimpor.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else if (hasData) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.table_rows_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Total baris data: ${state.previewRows.length}  •  Menampilkan ${limitPreviewRows(state.previewRows).length} baris pertama',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.primary.withValues(alpha: 0.08),
                  ),
                  border: TableBorder.all(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  columns: state.headers
                      .map(
                        (h) => DataColumn(
                          label: Text(
                            h,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  rows: limitPreviewRows(state.previewRows).map((row) {
                    return DataRow(
                      cells: List.generate(state.headers.length, (i) {
                        final value =
                            i < row.values.length ? row.values[i] : '';
                        return DataCell(Text(
                          value,
                          style: const TextStyle(fontSize: 13),
                        ));
                      }),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ] else
          const Spacer(),

        // Navigation buttons
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => notifier.goToStep(1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: canProceed ? () => notifier.goToStep(3) : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Lanjut ke Pemetaan'),
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
