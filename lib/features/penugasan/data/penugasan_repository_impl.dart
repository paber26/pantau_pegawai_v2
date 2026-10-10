import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/penugasan_model.dart';
import 'penugasan_repository.dart';

class PenugasanRepositoryImpl implements PenugasanRepository {
  final ApiClient _api;

  PenugasanRepositoryImpl(this._api);

  @override
  Future<List<PenugasanModel>> getByKegiatanId(String kegiatanId) async {
    try {
      final data = await _api.get(
        '/api/penugasan',
        query: {'kegiatan_id': kegiatanId},
      ) as List;
      return data
          .map((e) => PenugasanModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal memuat penugasan: ${e.toString()}');
    }
  }

  @override
  Future<void> assign({
    required String userId,
    required String kegiatanId,
  }) async {
    try {
      await _api.post('/api/penugasan', body: {
        'user_id': userId,
        'kegiatan_id': kegiatanId,
      });
    } on AppException catch (e) {
      throw AppException('Gagal assign pegawai: ${e.message}', code: e.code);
    } catch (e) {
      throw AppException('Gagal assign pegawai: ${e.toString()}');
    }
  }

  @override
  Future<void> unassign({
    required String userId,
    required String kegiatanId,
  }) async {
    try {
      await _api.delete('/api/penugasan', query: {
        'user_id': userId,
        'kegiatan_id': kegiatanId,
      });
    } on AppException catch (e) {
      throw AppException('Gagal unassign pegawai: ${e.message}', code: e.code);
    } catch (e) {
      throw AppException('Gagal unassign pegawai: ${e.toString()}');
    }
  }
}
