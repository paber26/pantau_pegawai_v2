import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/bulk_import_result.dart';
import '../domain/kegiatan_model.dart';
import 'kegiatan_repository.dart';

class KegiatanRepositoryImpl implements KegiatanRepository {
  final ApiClient _api;

  KegiatanRepositoryImpl(this._api);

  String _date(DateTime d) => d.toIso8601String().split('T').first;

  Future<List<KegiatanModel>> _list(Map<String, String?> query) async {
    final data = await _api.get('/api/kegiatan', query: query) as List;
    return data
        .map((e) => KegiatanModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<KegiatanModel>> getAll() async {
    try {
      return await _list({});
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal memuat kegiatan: ${e.toString()}');
    }
  }

  @override
  Future<List<KegiatanModel>> getByUserId(String userId) async {
    try {
      return await _list({'assigned_to': userId});
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal memuat kegiatan: ${e.toString()}');
    }
  }

  @override
  Future<KegiatanModel> getById(String id) async {
    try {
      final data = await _api.get('/api/kegiatan/$id');
      return KegiatanModel.fromMap(data as Map<String, dynamic>);
    } catch (e) {
      throw const AppException('Kegiatan tidak ditemukan');
    }
  }

  @override
  Future<KegiatanModel> create({
    required String judul,
    String? deskripsi,
    required DateTime deadline,
  }) async {
    try {
      final data = await _api.post('/api/kegiatan', body: {
        'judul': judul,
        'deskripsi': deskripsi,
        'deadline': _date(deadline),
      });
      return KegiatanModel.fromMap(data as Map<String, dynamic>);
    } on AppException catch (e) {
      throw AppException('Gagal membuat kegiatan: ${e.message}', code: e.code);
    } catch (e) {
      throw AppException('Gagal membuat kegiatan: ${e.toString()}');
    }
  }

  @override
  Future<KegiatanModel> update({
    required String id,
    required String judul,
    String? deskripsi,
    required DateTime deadline,
  }) async {
    try {
      final data = await _api.patch('/api/kegiatan/$id', body: {
        'judul': judul,
        'deskripsi': deskripsi,
        'deadline': _date(deadline),
      });
      return KegiatanModel.fromMap(data as Map<String, dynamic>);
    } on AppException catch (e) {
      throw AppException('Gagal mengupdate kegiatan: ${e.message}',
          code: e.code);
    } catch (e) {
      throw AppException('Gagal mengupdate kegiatan: ${e.toString()}');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _api.delete('/api/kegiatan/$id');
    } on AppException catch (e) {
      throw AppException('Gagal menghapus kegiatan: ${e.message}',
          code: e.code);
    } catch (e) {
      throw AppException('Gagal menghapus kegiatan: ${e.toString()}');
    }
  }

  @override
  Future<BulkImportResult> bulkImport(
      List<String> judulList, DateTime deadline) async {
    try {
      // Judul yang sudah ada dilewati oleh server.
      final data = await _api.post('/api/kegiatan/bulk', body: {
        'judul_list': judulList,
        'deadline': _date(deadline),
      }) as Map<String, dynamic>;
      return BulkImportResult(
        inserted: data['inserted'] as int,
        skipped: data['skipped'] as int,
      );
    } on AppException catch (e) {
      throw AppException('Gagal melakukan bulk import: ${e.message}',
          code: e.code);
    } catch (e) {
      throw AppException('Gagal melakukan bulk import: ${e.toString()}');
    }
  }
}
