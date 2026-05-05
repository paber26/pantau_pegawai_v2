import 'column_mapping_model.dart';
import 'sheet_row_model.dart';
import 'table_schema_config.dart';
import 'validation_result_model.dart';

/// Memvalidasi setiap baris data berdasarkan pemetaan kolom dan skema tabel tujuan.
///
/// Untuk setiap baris:
/// - Kolom `required: true` tidak boleh kosong/null.
/// - Kolom bertipe `date` harus dapat diparse (ISO 8601, dd/MM/yyyy, atau MM/dd/yyyy).
/// - Kolom bertipe `timestamp` harus dapat diparse oleh [DateTime.tryParse].
///
/// Mengembalikan [ValidationResultModel] dengan ringkasan hasil validasi.
ValidationResultModel validateRows(
  List<SheetRowModel> rows,
  List<String> headers,
  List<ColumnMappingModel> mappings,
  String targetTable,
) {
  final schema = kSupabaseTableSchemas[targetTable] ?? [];
  final errors = <RowValidationError>[];
  int invalidRowCount = 0;

  for (final row in rows) {
    // Buat map {sourceColumn: value} dari headers dan row.values
    final rowMap = <String, String>{};
    for (int i = 0; i < headers.length; i++) {
      rowMap[headers[i]] = i < row.values.length ? row.values[i] : '';
    }

    bool rowHasError = false;

    for (final mapping in mappings) {
      // Lewati mapping yang diabaikan atau tidak punya targetColumn
      if (mapping.isIgnored || mapping.targetColumn == null) continue;

      final targetColumnName = mapping.targetColumn!;
      final value = rowMap[mapping.sourceColumn] ?? '';

      // Cari definisi kolom dari skema
      final colDef =
          schema.where((d) => d.name == targetColumnName).firstOrNull;
      if (colDef == null) continue;

      // Validasi required
      if (colDef.required && value.trim().isEmpty) {
        errors.add(RowValidationError(
          rowIndex: row.rowIndex,
          columnName: targetColumnName,
          value: value,
          message: 'Kolom "$targetColumnName" wajib diisi.',
        ));
        rowHasError = true;
        continue;
      }

      // Validasi tipe date
      if (colDef.type == 'date' && value.trim().isNotEmpty) {
        if (!_isValidDate(value.trim())) {
          errors.add(RowValidationError(
            rowIndex: row.rowIndex,
            columnName: targetColumnName,
            value: value,
            message:
                'Nilai "$value" pada kolom "$targetColumnName" bukan format tanggal yang valid '
                '(gunakan YYYY-MM-DD, dd/MM/yyyy, atau MM/dd/yyyy).',
          ));
          rowHasError = true;
        }
      }

      // Validasi tipe timestamp
      if (colDef.type == 'timestamp' && value.trim().isNotEmpty) {
        if (DateTime.tryParse(value.trim()) == null) {
          errors.add(RowValidationError(
            rowIndex: row.rowIndex,
            columnName: targetColumnName,
            value: value,
            message:
                'Nilai "$value" pada kolom "$targetColumnName" bukan format timestamp yang valid.',
          ));
          rowHasError = true;
        }
      }
    }

    if (rowHasError) invalidRowCount++;
  }

  final validRowCount = rows.length - invalidRowCount;

  return ValidationResultModel(
    totalRows: rows.length,
    validRows: validRowCount,
    invalidRows: invalidRowCount,
    errors: errors,
  );
}

/// Mengecek apakah ada kolom `required: true` di skema tabel [targetTable]
/// yang tidak memiliki mapping aktif (tidak ada [ColumnMappingModel] dengan
/// `targetColumn == def.name` dan `isIgnored == false`).
bool hasUnmappedRequiredColumns(
  List<ColumnMappingModel> mappings,
  String targetTable,
) {
  final schema = kSupabaseTableSchemas[targetTable] ?? [];

  for (final def in schema) {
    if (!def.required) continue;

    final hasActiveMapping = mappings.any(
      (m) => m.targetColumn == def.name && !m.isIgnored,
    );

    if (!hasActiveMapping) return true;
  }

  return false;
}

/// Mencoba mem-parse string tanggal dalam format ISO 8601, dd/MM/yyyy, atau MM/dd/yyyy.
bool _isValidDate(String value) {
  // Coba ISO 8601 / format standar Dart
  if (DateTime.tryParse(value) != null) return true;

  // Coba dd/MM/yyyy
  if (_tryParseDdMmYyyy(value) != null) return true;

  // Coba MM/dd/yyyy
  if (_tryParseMmDdYyyy(value) != null) return true;

  return false;
}

DateTime? _tryParseDdMmYyyy(String value) {
  final parts = value.split('/');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  try {
    final date = DateTime(year, month, day);
    // Verifikasi tidak ada overflow (misal: 31/02/2024)
    if (date.day != day || date.month != month || date.year != year) {
      return null;
    }
    return date;
  } catch (_) {
    return null;
  }
}

DateTime? _tryParseMmDdYyyy(String value) {
  final parts = value.split('/');
  if (parts.length != 3) return null;
  final month = int.tryParse(parts[0]);
  final day = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  try {
    final date = DateTime(year, month, day);
    if (date.day != day || date.month != month || date.year != year) {
      return null;
    }
    return date;
  } catch (_) {
    return null;
  }
}
