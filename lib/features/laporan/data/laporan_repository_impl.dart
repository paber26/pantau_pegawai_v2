import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/laporan_model.dart';
import 'laporan_repository.dart';

class LaporanRepositoryImpl implements LaporanRepository {
  final ApiClient _api;

  LaporanRepositoryImpl(this._api);

  Future<List<LaporanModel>> _list(Map<String, String?> query) async {
    final data = await _api.get('/api/laporan', query: query) as List;
    return data
        .map((e) => LaporanModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<LaporanModel>> getAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? userId,
    String? kegiatanId,
  }) async {
    try {
      // Hanya satu filter yang dipakai, dengan prioritas:
      // user → kegiatan → rentang tanggal.
      if (userId != null) return await _list({'user_id': userId});
      if (kegiatanId != null) return await _list({'kegiatan_id': kegiatanId});
      return await _list({
        'from': fromDate?.toUtc().toIso8601String(),
        'to': toDate?.toUtc().toIso8601String(),
      });
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal memuat laporan: ${e.toString()}');
    }
  }

  @override
  Future<List<LaporanModel>> getByUserId(String userId) async {
    try {
      return await _list({'user_id': userId});
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal memuat riwayat laporan: ${e.toString()}');
    }
  }

  @override
  Future<LaporanModel> getById(String id) async {
    try {
      final data = await _api.get('/api/laporan/$id');
      return LaporanModel.fromMap(data as Map<String, dynamic>);
    } catch (e) {
      throw const AppException('Laporan tidak ditemukan');
    }
  }

  @override
  Future<LaporanModel> create({
    required String userId,
    required String kegiatanId,
    required Uint8List imageBytes,
    required String pegawaiNama,
    String? deskripsi,
  }) async {
    try {
      // 1. Upload foto ke Google Drive lewat API
      final imageUrl = await _api.uploadPhoto(
        bytes: imageBytes,
        tanggal: DateTime.now(),
      );

      // 2. Simpan metadata (user ditentukan server dari akun yang login)
      final data = await _api.post('/api/laporan', body: {
        'kegiatan_id': kegiatanId,
        'image_url': imageUrl,
        'deskripsi': deskripsi,
      });

      return LaporanModel.fromMap(data as Map<String, dynamic>);
    } on AppException catch (e) {
      throw AppException('Gagal upload laporan: ${e.message}', code: e.code);
    } catch (e) {
      throw AppException('Gagal upload laporan: ${e.toString()}');
    }
  }
}
