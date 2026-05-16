import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/dokumentasi_model.dart';
import 'dokumentasi_repository.dart';

class DokumentasiRepositoryImpl implements DokumentasiRepository {
  final SupabaseClient _client;

  DokumentasiRepositoryImpl(this._client);

  @override
  Future<List<DokumentasiModel>> getAll({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Pagination: Supabase default limit 1000 baris per query.
      // Untuk dataset > 1000 baris kita harus pakai range() berulang
      // sampai semua baris terambil.
      const pageSize = 1000;
      final all = <DokumentasiModel>[];
      var page = 0;
      final fromStr = fromDate?.toIso8601String().split('T').first;
      final toStr = toDate?.toIso8601String().split('T').first;

      while (true) {
        final from = page * pageSize;
        final to = from + pageSize - 1;

        // Pola query yang sama dengan/tanpa filter tanggal.
        final query = _client
            .from('dokumentasi')
            .select('*, users(nama, jabatan, unit_kerja)');
        final filtered = (fromStr != null && toStr != null)
            ? query.gte('tanggal_kegiatan', fromStr).lte(
                  'tanggal_kegiatan',
                  toStr,
                )
            : query;
        final data = await filtered
            .order('tanggal_kegiatan', ascending: false)
            .order('created_at', ascending: false)
            .range(from, to);

        final batch =
            (data as List).map((e) => DokumentasiModel.fromMap(e)).toList();
        all.addAll(batch);

        if (batch.length < pageSize) break;
        page += 1;
      }

      return all;
    } catch (e) {
      throw AppException('Gagal memuat dokumentasi: ${e.toString()}');
    }
  }

  @override
  Future<List<DokumentasiModel>> getByUserId(String userId) async {
    try {
      // Pagination untuk antisipasi user yang punya >1000 dokumentasi.
      const pageSize = 1000;
      final all = <DokumentasiModel>[];
      var page = 0;

      while (true) {
        final from = page * pageSize;
        final to = from + pageSize - 1;

        final data = await _client
            .from('dokumentasi')
            .select('*, users(nama, jabatan, unit_kerja)')
            .eq('user_id', userId)
            .order('tanggal_kegiatan', ascending: false)
            .order('created_at', ascending: false)
            .range(from, to);

        final batch =
            (data as List).map((e) => DokumentasiModel.fromMap(e)).toList();
        all.addAll(batch);

        if (batch.length < pageSize) break;
        page += 1;
      }

      return all;
    } catch (e) {
      throw AppException('Gagal memuat dokumentasi: ${e.toString()}');
    }
  }

  @override
  Future<DokumentasiModel> create({
    required String userId,
    required String pegawaiNama,
    required String proyek,
    required DateTime tanggalKegiatan,
    Uint8List? imageBytes,
    String? catatan,
  }) async {
    try {
      String? imageUrl;

      if (imageBytes != null) {
        imageUrl = await _uploadToGoogleDrive(
          imageBytes: imageBytes,
          pegawaiNama: pegawaiNama,
          tanggal: AppDateUtils.toFolderDate(tanggalKegiatan),
        );
      }

      final data = await _client
          .from('dokumentasi')
          .insert({
            'user_id': userId,
            'pegawai_nama': pegawaiNama,
            'proyek': proyek,
            'tanggal_kegiatan':
                tanggalKegiatan.toIso8601String().split('T').first,
            'image_url': imageUrl,
            'catatan': catatan,
            'link': imageUrl,
          })
          .select('*, users(nama, jabatan, unit_kerja)')
          .single();

      return DokumentasiModel.fromMap(data);
    } catch (e) {
      throw AppException('Gagal menyimpan dokumentasi: ${e.toString()}');
    }
  }

  @override
  Future<List<DokumentasiModel>> getByYear(int year) async {
    try {
      // Pagination: lihat catatan di getAll().
      const pageSize = 1000;
      final all = <DokumentasiModel>[];
      var page = 0;

      while (true) {
        final from = page * pageSize;
        final to = from + pageSize - 1;

        final data = await _client
            .from('dokumentasi')
            .select('*, users(nama, jabatan, unit_kerja)')
            .gte('tanggal_kegiatan', '$year-01-01')
            .lte('tanggal_kegiatan', '$year-12-31')
            .order('tanggal_kegiatan', ascending: false)
            .range(from, to);

        final batch =
            (data as List).map((e) => DokumentasiModel.fromMap(e)).toList();
        all.addAll(batch);

        if (batch.length < pageSize) break;
        page += 1;
      }

      return all;
    } catch (e) {
      throw AppException(
          'Gagal memuat dokumentasi tahun $year: ${e.toString()}');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('dokumentasi').delete().eq('id', id);
    } catch (e) {
      throw AppException('Gagal menghapus dokumentasi: ${e.toString()}');
    }
  }

  Future<String> _uploadToGoogleDrive({
    required Uint8List imageBytes,
    required String pegawaiNama,
    required String tanggal,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw const AppException('Sesi tidak valid');

    final timestamp = AppDateUtils.toTimestamp(DateTime.now());
    final filename = 'foto_$timestamp.jpg';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(SupabaseConstants.uploadDriveFunctionUrl),
    );

    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    request.fields['pegawai_nama'] = pegawaiNama;
    request.fields['tanggal'] = tanggal;
    request.fields['filename'] = filename;

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw AppException('Upload foto gagal: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['image_url'] as String;
  }
}
