import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/column_mapping_model.dart';
import '../../domain/row_validator.dart';
import '../../domain/table_schema_config.dart';
import '../import_sheets_provider.dart';

const _kTargetTables = ['users', 'kegiatan', 'laporan', 'dokumentasi'];
const _kIgnoreOption = 'Abaikan';

class Step3MappingScreen extends ConsumerWidget {
  const Step3MappingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importSheetsNotifierProvider);
    final notifier = ref.read(importSheetsNotifierProvider.notifier);

    final targetTable = state.targetTable;
    final schema = targetTable != null
        ? (kSupabaseTableSchemas[targetTable] ?? <ColumnDefinition>[])
        : <ColumnDefinition>[];
    final hasUnmapped = targetTable != null &&
        hasUnmappedRequiredColumns(state.columnMappings, targetTable);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pemetaan Kolom',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih tabel tujuan dan petakan kolom sumber ke kolom tujuan.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              // Target table dropdown
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tabel Tujuan',
                  prefixIcon: Icon(Icons.table_chart_outlined),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: targetTable,
                    isExpanded: true,
                    isDense: true,
                    hint: const Text('Pilih tabel'),
                    items: _kTargetTables
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(t),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) notifier.setTargetTable(value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // Warning banner
        if (hasUnmapped)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: AppColors.warning, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ada kolom wajib yang belum dipetakan. Harap petakan semua kolom wajib sebelum melanjutkan.',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (hasUnmapped) const SizedBox(height: 12),

        // Mapping rows
        if (targetTable == null)
          const Expanded(
            child: Center(
              child: Text(
                'Pilih tabel tujuan terlebih dahulu.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else if (state.columnMappings.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'Tidak ada kolom sumber untuk dipetakan.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              itemCount: state.columnMappings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final mapping = state.columnMappings[index];
                return _MappingRow(
                  mapping: mapping,
                  schema: schema,
                  onChanged: (newMapping) =>
                      notifier.updateMapping(index, newMapping),
                );
              },
            ),
          ),

        // Navigation buttons
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => notifier.goToStep(2),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: (targetTable != null && !hasUnmapped)
                    ? () => notifier.goToStep(4)
                    : null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Konfirmasi Pemetaan'),
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

class _MappingRow extends StatelessWidget {
  final ColumnMappingModel mapping;
  final List<ColumnDefinition> schema;
  final ValueChanged<ColumnMappingModel> onChanged;

  const _MappingRow({
    required this.mapping,
    required this.schema,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentTarget =
        mapping.isIgnored ? _kIgnoreOption : mapping.targetColumn;

    // Build dropdown items: schema columns + "Abaikan"
    final dropdownItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: _kIgnoreOption,
        child: Text(
          _kIgnoreOption,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
      ...schema.map(
        (col) => DropdownMenuItem(
          value: col.name,
          child: Row(
            children: [
              Expanded(child: Text(col.name)),
              if (col.required)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Wajib',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Source column label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kolom Sumber',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
                  Text(
                    mapping.sourceColumn,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward,
                size: 16, color: AppColors.textHint),
            const SizedBox(width: 8),
            // Target column dropdown
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Kolom Tujuan',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentTarget ?? _kIgnoreOption,
                    isExpanded: true,
                    isDense: true,
                    items: dropdownItems,
                    onChanged: (value) {
                      if (value == null) return;
                      if (value == _kIgnoreOption) {
                        onChanged(mapping.copyWith(
                          targetColumn: null,
                          isIgnored: true,
                        ));
                      } else {
                        onChanged(mapping.copyWith(
                          targetColumn: value,
                          isIgnored: false,
                        ));
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
