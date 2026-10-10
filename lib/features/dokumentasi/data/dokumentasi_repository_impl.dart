import 'dart:typed_data';

import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/dokumentasi_model.dart';
import 'dokumentasi_repository.dart';

class DokumentasiRepositoryImpl implements DokumentasiRepository {
  final ApiClient _api;

  DokumentasiRepositoryImpl(this._api);

  String _date(DateTime d) => d.toIso8601String().split('T').first;

  Future<List<DokumentasiModel>> _list(Map<String, String?> query) async {
    // API mengembalikan semua baris yang cocok (tidak ada batas 1000 baris).
    final data = await _api.get('/api/dokumentasi', query: query) as List;
    return data
        .map((e) => DokumentasiModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<DokumentasiModel>> getAll({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      // Filter tanggal hanya dipakai bila keduanya diisi.
      final hasRange = fromDate != null && toDate != null;
      return await _list({
        'from': hasRange ? _date(fromDate) : null,
        'to': hasRange ? _date(toDate) : null,
      });
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal memuat dokumentasi: ${e.toString()}');
    }
  }

  @override
  Future<List<DokumentasiModel>> getByUserId(String userId) async {
    try {
      // Diurutkan server berdasarkan waktu penambahan (created_at) terbaru,
      // untuk halaman "Riwayat Saya".
      return await _list({'user_id': userId});
    } on AppException {
      rethrow;
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
    // userId & pegawaiNama ditentukan server dari akun yang login.
    try {
      String? imageUrl;

      if (imageBytes != null) {
        imageUrl = await _api.uploadPhoto(
          bytes: imageBytes,
          tanggal: tanggalKegiatan,
        );
      }

      final data = await _api.post('/api/dokumentasi', body: {
        'proyek': proyek,
        'tanggal_kegiatan': _date(tanggalKegiatan),
        'image_url': imageUrl,
        'catatan': catatan,
        'link': imageUrl,
      });

      return DokumentasiModel.fromMap(data as Map<String, dynamic>);
    } on AppException catch (e) {
      throw AppException('Gagal menyimpan dokumentasi: ${e.message}',
          code: e.code);
    } catch (e) {
      throw AppException('Gagal menyimpan dokumentasi: ${e.toString()}');
    }
  }

  @override
  Future<DokumentasiModel> update({
    required String id,
    required String pegawaiNama,
    required String proyek,
    required DateTime tanggalKegiatan,
    Uint8List? newImageBytes,
    String? existingImageUrl,
    String? catatan,
  }) async {
    try {
      // Default: pertahankan gambar lama. Jika ada gambar baru, unggah dan
      // ganti URL-nya.
      String? imageUrl = existingImageUrl;

      if (newImageBytes != null) {
        imageUrl = await _api.uploadPhoto(
          bytes: newImageBytes,
          tanggal: tanggalKegiatan,
        );
      }

      final data = await _api.patch('/api/dokumentasi/$id', body: {
        'proyek': proyek,
        'tanggal_kegiatan': _date(tanggalKegiatan),
        'image_url': imageUrl,
        'catatan': catatan,
        'link': imageUrl,
      });

      return DokumentasiModel.fromMap(data as Map<String, dynamic>);
    } on AppException catch (e) {
      throw AppException('Gagal memperbarui dokumentasi: ${e.message}',
          code: e.code);
    } catch (e) {
      throw AppException('Gagal memperbarui dokumentasi: ${e.toString()}');
    }
  }

  @override
  Future<List<DokumentasiModel>> getByYear(int year) async {
    try {
      return await _list({'year': '$year'});
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
          'Gagal memuat dokumentasi tahun $year: ${e.toString()}');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _api.delete('/api/dokumentasi/$id');
    } on AppException catch (e) {
      throw AppException('Gagal menghapus dokumentasi: ${e.message}',
          code: e.code);
    } catch (e) {
      throw AppException('Gagal menghapus dokumentasi: ${e.toString()}');
    }
  }
}
