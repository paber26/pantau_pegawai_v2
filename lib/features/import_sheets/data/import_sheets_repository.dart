import '../domain/import_result_model.dart';
import '../domain/sheet_metadata_model.dart';
import '../domain/sheet_row_model.dart';

abstract class ImportSheetsRepository {
  /// Mengambil metadata spreadsheet (daftar sheet) dari Google Sheets API.
  Future<List<SheetMetadataModel>> getSheetList(String spreadsheetId);

  /// Mengambil data dari sheet tertentu (baris pertama/header di-skip).
  Future<List<SheetRowModel>> getSheetData(
    String spreadsheetId,
    String sheetName,
  );

  /// Mengambil baris pertama sheet sebagai daftar nama kolom (headers).
  Future<List<String>> getSheetHeaders(
    String spreadsheetId,
    String sheetName,
  );

  /// Mengirim batch data ke Edge Function untuk diimpor ke Supabase.
  Future<ImportResultModel> importBatch({
    required String targetTable,
    required List<Map<String, dynamic>> rows,
    required String jwtToken,
  });
}
