import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/import_result_model.dart';
import '../domain/sheet_metadata_model.dart';
import '../domain/sheet_row_model.dart';
import 'import_sheets_repository.dart';

class ImportSheetsRepositoryImpl implements ImportSheetsRepository {
  final http.Client _httpClient;

  ImportSheetsRepositoryImpl({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  static const String _apiKey = SupabaseConstants.googleSheetsApiKey;

  @override
  Future<List<SheetMetadataModel>> getSheetList(String spreadsheetId) async {
    return _withRetry(
      () async {
        final uri = Uri.parse(
          'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId'
          '?key=$_apiKey&fields=sheets.properties',
        );
        final response = await _httpClient.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return (data['sheets'] as List)
              .map((s) => SheetMetadataModel.fromMap(s as Map<String, dynamic>))
              .toList();
        } else if (response.statusCode == 403) {
          throw const AppException(
            'Spreadsheet tidak dapat diakses. Pastikan spreadsheet dapat diakses oleh siapa saja yang memiliki tautan.',
            code: '403',
          );
        } else if (response.statusCode == 404) {
          throw const AppException(
            'Spreadsheet tidak ditemukan. Periksa ID atau URL.',
            code: '404',
          );
        } else {
          throw AppException(
            'Gagal mengambil daftar sheet. Status: ${response.statusCode}',
            code: '${response.statusCode}',
          );
        }
      },
      maxAttempts: 3,
      delay: const Duration(seconds: 2),
      timeout: const Duration(seconds: 30),
    );
  }

  @override
  Future<List<String>> getSheetHeaders(
    String spreadsheetId,
    String sheetName,
  ) async {
    return _withRetry(
      () async {
        // Ambil hanya baris pertama dengan range notation
        final range = Uri.encodeComponent('$sheetName!1:1');
        final uri = Uri.parse(
          'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId'
          '/values/$range?key=$_apiKey',
        );
        final response = await _httpClient.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final values = data['values'] as List?;

          if (values == null || values.isEmpty) {
            return <String>[];
          }

          // Baris pertama adalah header
          final headerRow = values.first as List;
          return headerRow.map((cell) => cell?.toString() ?? '').toList();
        } else if (response.statusCode == 403) {
          throw const AppException(
            'Spreadsheet tidak dapat diakses. Pastikan spreadsheet dapat diakses oleh siapa saja yang memiliki tautan.',
            code: '403',
          );
        } else if (response.statusCode == 404) {
          throw const AppException(
            'Spreadsheet tidak ditemukan. Periksa ID atau URL.',
            code: '404',
          );
        } else {
          throw AppException(
            'Gagal mengambil header sheet. Status: ${response.statusCode}',
            code: '${response.statusCode}',
          );
        }
      },
      maxAttempts: 3,
      delay: const Duration(seconds: 2),
      timeout: const Duration(seconds: 30),
    );
  }

  @override
  Future<List<SheetRowModel>> getSheetData(
    String spreadsheetId,
    String sheetName,
  ) async {
    return _withRetry(
      () async {
        final encodedSheetName = Uri.encodeComponent(sheetName);
        final uri = Uri.parse(
          'https://sheets.googleapis.com/v4/spreadsheets/$spreadsheetId'
          '/values/$encodedSheetName?key=$_apiKey',
        );
        final response = await _httpClient.get(uri);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final values = data['values'] as List?;

          // Jika values null atau kosong, kembalikan list kosong
          if (values == null || values.isEmpty) {
            return <SheetRowModel>[];
          }

          // Baris pertama adalah header — abaikan, mulai dari index 1
          final dataRows = values.skip(1).toList();

          return dataRows.asMap().entries.map((entry) {
            final rowIndex = entry.key + 1; // rowIndex dimulai dari 1
            final rowValues = (entry.value as List)
                .map((cell) => cell?.toString() ?? '')
                .toList();
            return SheetRowModel(rowIndex: rowIndex, values: rowValues);
          }).toList();
        } else if (response.statusCode == 403) {
          throw const AppException(
            'Spreadsheet tidak dapat diakses. Pastikan spreadsheet dapat diakses oleh siapa saja yang memiliki tautan.',
            code: '403',
          );
        } else if (response.statusCode == 404) {
          throw const AppException(
            'Spreadsheet tidak ditemukan. Periksa ID atau URL.',
            code: '404',
          );
        } else {
          throw AppException(
            'Gagal mengambil data sheet. Status: ${response.statusCode}',
            code: '${response.statusCode}',
          );
        }
      },
      maxAttempts: 3,
      delay: const Duration(seconds: 2),
      timeout: const Duration(seconds: 30),
    );
  }

  @override
  Future<ImportResultModel> importBatch({
    required String targetTable,
    required List<Map<String, dynamic>> rows,
    required String jwtToken,
  }) async {
    final uri = Uri.parse(SupabaseConstants.importSheetsFunctionUrl);
    final body = jsonEncode({'targetTable': targetTable, 'rows': rows});

    final http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $jwtToken',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const AppException(
        'Koneksi ke server timeout. Silakan coba lagi.',
        code: 'timeout',
      );
    } on SocketException {
      throw const AppException(
        'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        code: 'network_error',
      );
    }

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseImportResult(data);
    } else if (response.statusCode == 403) {
      throw const AppException(
        'Sesi tidak valid, silakan login ulang.',
        code: '403',
      );
    } else {
      throw AppException(
        'Gagal mengimpor data. Status: ${response.statusCode}',
        code: '${response.statusCode}',
      );
    }
  }

  ImportResultModel _parseImportResult(Map<String, dynamic> data) {
    final errors = (data['errors'] as List? ?? [])
        .map((e) => ImportRowError(
              rowIndex: (e['rowIndex'] as num?)?.toInt() ?? 0,
              originalData: (e['data'] as Map?)?.cast<String, dynamic>() ?? {},
              message: e['message']?.toString() ?? '',
            ))
        .toList();

    return ImportResultModel(
      totalProcessed:
          ((data['imported'] as num? ?? 0) + (data['failed'] as num? ?? 0))
              .toInt(),
      successCount: (data['imported'] as num? ?? 0).toInt(),
      failedCount: (data['failed'] as num? ?? 0).toInt(),
      duration: Duration.zero,
      errors: errors,
    );
  }
}

/// Fungsi retry dengan timeout untuk operasi HTTP yang dapat gagal sementara.
Future<T> _withRetry<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration delay = const Duration(seconds: 2),
  Duration timeout = const Duration(seconds: 30),
}) async {
  for (int attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException {
      if (attempt == maxAttempts) rethrow;
      await Future.delayed(delay);
    } on SocketException {
      if (attempt == maxAttempts) rethrow;
      await Future.delayed(delay);
    }
  }
  throw AppException('Gagal setelah $maxAttempts percobaan');
}
