import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/import_sheets_repository.dart';
import '../data/import_sheets_repository_impl.dart';
import '../domain/batch_utils.dart';
import '../domain/column_mapping_model.dart';
import '../domain/import_result_model.dart';
import '../domain/row_validator.dart';
import '../domain/sheet_metadata_model.dart';
import '../domain/sheet_row_model.dart';
import '../domain/validation_result_model.dart';

part 'import_sheets_provider.g.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ImportWizardState {
  final int currentStep;
  final String? spreadsheetId;
  final List<String> headers;
  final List<SheetMetadataModel> sheetList;
  final String? selectedSheet;
  final List<SheetRowModel> previewRows;
  final String? targetTable;
  final List<ColumnMappingModel> columnMappings;
  final ValidationResultModel? validationResult;
  final ImportResultModel? importResult;
  final bool isLoading;
  final String? errorMessage;

  const ImportWizardState({
    this.currentStep = 1,
    this.spreadsheetId,
    this.headers = const [],
    this.sheetList = const [],
    this.selectedSheet,
    this.previewRows = const [],
    this.targetTable,
    this.columnMappings = const [],
    this.validationResult,
    this.importResult,
    this.isLoading = false,
    this.errorMessage,
  });

  ImportWizardState copyWith({
    int? currentStep,
    String? spreadsheetId,
    List<String>? headers,
    List<SheetMetadataModel>? sheetList,
    String? selectedSheet,
    List<SheetRowModel>? previewRows,
    String? targetTable,
    List<ColumnMappingModel>? columnMappings,
    ValidationResultModel? validationResult,
    ImportResultModel? importResult,
    bool? isLoading,
    String? errorMessage,
    // Sentinel untuk menghapus nilai nullable
    bool clearSpreadsheetId = false,
    bool clearSelectedSheet = false,
    bool clearTargetTable = false,
    bool clearValidationResult = false,
    bool clearImportResult = false,
    bool clearErrorMessage = false,
  }) {
    return ImportWizardState(
      currentStep: currentStep ?? this.currentStep,
      spreadsheetId:
          clearSpreadsheetId ? null : (spreadsheetId ?? this.spreadsheetId),
      headers: headers ?? this.headers,
      sheetList: sheetList ?? this.sheetList,
      selectedSheet:
          clearSelectedSheet ? null : (selectedSheet ?? this.selectedSheet),
      previewRows: previewRows ?? this.previewRows,
      targetTable: clearTargetTable ? null : (targetTable ?? this.targetTable),
      columnMappings: columnMappings ?? this.columnMappings,
      validationResult: clearValidationResult
          ? null
          : (validationResult ?? this.validationResult),
      importResult:
          clearImportResult ? null : (importResult ?? this.importResult),
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

@riverpod
ImportSheetsRepository importSheetsRepository(Ref ref) {
  return ImportSheetsRepositoryImpl();
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

@riverpod
class ImportSheetsNotifier extends _$ImportSheetsNotifier {
  @override
  ImportWizardState build() => const ImportWizardState();

  ImportSheetsRepository get _repo => ref.read(importSheetsRepositoryProvider);

  // -------------------------------------------------------------------------
  // Step 1 — Konfigurasi sumber
  // -------------------------------------------------------------------------

  void setSpreadsheetId(String id) {
    state = state.copyWith(
      spreadsheetId: id,
      clearErrorMessage: true,
    );
  }

  Future<void> loadSheetList() async {
    final id = state.spreadsheetId;
    if (id == null || id.isEmpty) return;

    state = state.copyWith(isLoading: true, clearErrorMessage: true);
    try {
      final sheets = await _repo.getSheetList(id);
      state = state.copyWith(
        isLoading: false,
        sheetList: sheets,
        currentStep: 2,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Step 2 — Pratinjau data
  // -------------------------------------------------------------------------

  Future<void> selectSheet(String sheetName) async {
    final id = state.spreadsheetId;
    if (id == null || id.isEmpty) return;

    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      selectedSheet: sheetName,
    );

    try {
      // Ambil semua data sheet (baris pertama sudah di-skip oleh repository,
      // sehingga kita perlu mengambil headers secara terpisah).
      final rows = await _repo.getSheetData(id, sheetName);
      final headers = await _getSheetHeaders(id, sheetName);

      state = state.copyWith(
        isLoading: false,
        headers: headers,
        previewRows: rows,
        // Reset mapping & validasi saat sheet berubah
        columnMappings: const [],
        clearValidationResult: true,
        clearImportResult: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Step 3 — Pemetaan kolom
  // -------------------------------------------------------------------------

  void setTargetTable(String table) {
    // Buat default mapping: setiap header → targetColumn null, isIgnored false
    final defaultMappings = state.headers
        .map(
          (header) => ColumnMappingModel(
            sourceColumn: header,
            targetColumn: null,
            isIgnored: false,
          ),
        )
        .toList();

    state = state.copyWith(
      targetTable: table,
      columnMappings: defaultMappings,
      clearValidationResult: true,
    );
  }

  void updateMapping(int index, ColumnMappingModel mapping) {
    final updated = List<ColumnMappingModel>.from(state.columnMappings);
    if (index >= 0 && index < updated.length) {
      updated[index] = mapping;
      state = state.copyWith(columnMappings: updated);
    }
  }

  // -------------------------------------------------------------------------
  // Step 4 — Validasi
  // -------------------------------------------------------------------------

  void runValidation() {
    final table = state.targetTable;
    if (table == null) return;

    final result = validateRows(
      state.previewRows,
      state.headers,
      state.columnMappings,
      table,
    );

    state = state.copyWith(validationResult: result);
  }

  // -------------------------------------------------------------------------
  // Step 5 — Impor
  // -------------------------------------------------------------------------

  Future<void> startImport() async {
    final table = state.targetTable;
    final validationResult = state.validationResult;
    if (table == null || validationResult == null) return;

    final jwtToken =
        Supabase.instance.client.auth.currentSession?.accessToken ?? '';

    // Kumpulkan indeks baris yang memiliki error
    final errorRowIndices =
        validationResult.errors.map((e) => e.rowIndex).toSet();

    // Ambil baris valid (tidak ada di errorRowIndices)
    final validRows = state.previewRows
        .where((row) => !errorRowIndices.contains(row.rowIndex))
        .toList();

    if (validRows.isEmpty) return;

    // Konversi baris valid ke List<Map<String, dynamic>> berdasarkan mappings
    final mappedRows = _convertRowsToMaps(validRows);

    // Bagi menjadi batch
    final batches = splitIntoBatches(mappedRows, batchSize: 100);

    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    int totalProcessed = 0;
    int totalSuccess = 0;
    int totalFailed = 0;
    final allErrors = <ImportRowError>[];
    final startTime = DateTime.now();

    try {
      for (final batch in batches) {
        final result = await _repo.importBatch(
          targetTable: table,
          rows: batch,
          jwtToken: jwtToken,
        );
        totalProcessed += result.totalProcessed;
        totalSuccess += result.successCount;
        totalFailed += result.failedCount;
        allErrors.addAll(result.errors);
      }

      final duration = DateTime.now().difference(startTime);
      final importResult = ImportResultModel(
        totalProcessed: totalProcessed,
        successCount: totalSuccess,
        failedCount: totalFailed,
        duration: duration,
        errors: allErrors,
      );

      state = state.copyWith(
        isLoading: false,
        importResult: importResult,
        currentStep: 5,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Navigasi
  // -------------------------------------------------------------------------

  void goToStep(int step) {
    if (step >= 1 && step <= 5) {
      state = state.copyWith(currentStep: step);
    }
  }

  // -------------------------------------------------------------------------
  // Reset
  // -------------------------------------------------------------------------

  void reset() {
    state = const ImportWizardState();
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /// Mengambil baris header dari sheet dengan memanggil [getSheetHeaders]
  /// pada repository.
  Future<List<String>> _getSheetHeaders(
    String spreadsheetId,
    String sheetName,
  ) async {
    return _repo.getSheetHeaders(spreadsheetId, sheetName);
  }

  /// Mengkonversi [SheetRowModel] ke [Map<String, dynamic>] berdasarkan
  /// [columnMappings] yang aktif (tidak diabaikan dan punya targetColumn).
  List<Map<String, dynamic>> _convertRowsToMaps(List<SheetRowModel> rows) {
    final activeMappings = state.columnMappings
        .where((m) => !m.isIgnored && m.targetColumn != null)
        .toList();

    final headers = state.headers;

    return rows.map((row) {
      final map = <String, dynamic>{};
      for (final mapping in activeMappings) {
        final sourceIndex = headers.indexOf(mapping.sourceColumn);
        if (sourceIndex >= 0 && sourceIndex < row.values.length) {
          map[mapping.targetColumn!] = row.values[sourceIndex];
        } else {
          map[mapping.targetColumn!] = null;
        }
      }
      return map;
    }).toList();
  }
}
