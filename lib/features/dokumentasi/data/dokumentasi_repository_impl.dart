import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
      var query = _client.from('dokumentasi').select('*, users(nama)');

      if (fromDate != null && toDate != null) {
        final data = await _client
            .from('dokumentasi')
            .select('*, users(nama)')
            .gte(
                'tanggal_kegiatan', fromDate.toIso8601String().split('T').first)
            .lte('tanggal_kegiatan', toDate.toIso8601String().split('T').first)
            .order('tanggal_kegiatan', ascending: false)
            .order('created_at', ascending: false);
        return (data as List).map((e) => DokumentasiModel.fromMap(e)).toList();
      }

      final data = await query
          .order('tanggal_kegiatan', ascending: false)
          .order('created_at', ascending: false);
      return (data as List).map((e) => DokumentasiModel.fromMap(e)).toList();
    } catch (e) {
      throw AppException('Gagal memuat dokumentasi: ${e.toString()}');
    }
  }

  @override
  Future<List<DokumentasiModel>> getByUserId(String userId) async {
    try {
      final data = await _client
          .from('dokumentasi')
          .select('*, users(nama)')
          .eq('user_id', userId)
          .order('tanggal_kegiatan', ascending: false)
          .order('created_at', ascending: false);
      return (data as List).map((e) => DokumentasiModel.fromMap(e)).toList();
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
    File? imageFile,
    List<int>? imageBytes,
    String? catatan,
    String? link,
  }) async {
    try {
      String? imageUrl;

      // Tentukan bytes yang akan diupload
      List<int>? bytesToUpload = imageBytes;
      if (bytesToUpload == null && imageFile != null && !kIsWeb) {
        bytesToUpload = await imageFile.readAsBytes();
      }

      if (bytesToUpload != null) {
        imageUrl = await _uploadToGoogleDrive(
          imageBytes: bytesToUpload,
          pegawaiNama: pegawaiNama,
          tanggal: AppDateUtils.toFolderDate(tanggalKegiatan),
        );
      }

      final data = await _client
          .from('dokumentasi')
          .insert({
            'user_id': userId,
            'proyek': proyek,
            'tanggal_kegiatan':
                tanggalKegiatan.toIso8601String().split('T').first,
            'image_url': imageUrl,
            'catatan': catatan,
            'link': link,
          })
          .select('*, users(nama)')
          .single();

      return DokumentasiModel.fromMap(data);
    } catch (e) {
      throw AppException('Gagal menyimpan dokumentasi: ${e.toString()}');
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
    required List<int> imageBytes,
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

    // Gunakan fromBytes — kompatibel dengan web dan mobile
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
