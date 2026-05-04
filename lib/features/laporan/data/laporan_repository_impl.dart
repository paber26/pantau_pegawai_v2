import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthException, StorageException;

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/date_utils.dart';
import '../domain/laporan_model.dart';
import 'laporan_repository.dart';

class LaporanRepositoryImpl implements LaporanRepository {
  final SupabaseClient _client;

  LaporanRepositoryImpl(this._client);

  @override
  Future<List<LaporanModel>> getAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? userId,
    String? kegiatanId,
  }) async {
    try {
      // Build query dengan filter bertahap
      var query = _client
          .from('laporan')
          .select('*, users(nama), kegiatan(judul)');

      // Filter harus dilakukan sebelum .order() karena supabase_flutter
      // mengembalikan PostgrestFilterBuilder dari .select()
      if (userId != null) {
        final data = await _client
            .from('laporan')
            .select('*, users(nama), kegiatan(judul)')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        return (data as List).map((e) => LaporanModel.fromMap(e)).toList();
      }

      if (kegiatanId != null) {
        final data = await _client
            .from('laporan')
            .select('*, users(nama), kegiatan(judul)')
            .eq('kegiatan_id', kegiatanId)
            .order('created_at', ascending: false);
        return (data as List).map((e) => LaporanModel.fromMap(e)).toList();
      }

      if (fromDate != null && toDate != null) {
        final data = await _client
            .from('laporan')
            .select('*, users(nama), kegiatan(judul)')
            .gte('created_at', fromDate.toIso8601String())
            .lte('created_at', toDate.toIso8601String())
            .order('created_at', ascending: false);
        return (data as List).map((e) => LaporanModel.fromMap(e)).toList();
      }

      if (fromDate != null) {
        final data = await _client
            .from('laporan')
            .select('*, users(nama), kegiatan(judul)')
            .gte('created_at', fromDate.toIso8601String())
            .order('created_at', ascending: false);
        return (data as List).map((e) => LaporanModel.fromMap(e)).toList();
      }

      if (toDate != null) {
        final data = await _client
            .from('laporan')
            .select('*, users(nama), kegiatan(judul)')
            .lte('created_at', toDate.toIso8601String())
            .order('created_at', ascending: false);
        return (data as List).map((e) => LaporanModel.fromMap(e)).toList();
      }

      final data = await query.order('created_at', ascending: false);
      return (data as List).map((e) => LaporanModel.fromMap(e)).toList();
    } catch (e) {
      throw AppException('Gagal memuat laporan: ${e.toString()}');
    }
  }

  @override
  Future<List<LaporanModel>> getByUserId(String userId) async {
    try {
      final data = await _client
          .from('laporan')
          .select('*, kegiatan(judul)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => LaporanModel.fromMap(e)).toList();
    } catch (e) {
      throw AppException('Gagal memuat riwayat laporan: ${e.toString()}');
    }
  }

  @override
  Future<LaporanModel> getById(String id) async {
    try {
      final data = await _client
          .from('laporan')
          .select('*, users(nama), kegiatan(judul)')
          .eq('id', id)
          .single();
      return LaporanModel.fromMap(data);
    } catch (e) {
      throw AppException('Laporan tidak ditemukan');
    }
  }

  @override
  Future<LaporanModel> create({
    required String userId,
    required String kegiatanId,
    required File imageFile,
    required String pegawaiNama,
    String? deskripsi,
  }) async {
    try {
      // 1. Upload foto ke Google Drive via Edge Function
      final imageUrl = await _uploadToGoogleDrive(
        imageFile: imageFile,
        pegawaiNama: pegawaiNama,
      );

      // 2. Simpan metadata ke Supabase
      final data = await _client
          .from('laporan')
          .insert({
            'user_id': userId,
            'kegiatan_id': kegiatanId,
            'image_url': imageUrl,
            'deskripsi': deskripsi,
          })
          .select('*, users(nama), kegiatan(judul)')
          .single();

      return LaporanModel.fromMap(data);
    } catch (e) {
      throw AppException('Gagal upload laporan: ${e.toString()}');
    }
  }

  Future<String> _uploadToGoogleDrive({
    required File imageFile,
    required String pegawaiNama,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw const AppException('Sesi tidak valid');

    final now = DateTime.now();
    final tanggal = AppDateUtils.toFolderDate(now);
    final timestamp = AppDateUtils.toTimestamp(now);
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
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw AppException(
          'Upload gagal: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['image_url'] as String;
  }
}
