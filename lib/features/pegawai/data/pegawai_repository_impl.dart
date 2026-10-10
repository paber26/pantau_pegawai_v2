import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/pegawai_model.dart';
import 'pegawai_repository.dart';

class PegawaiRepositoryImpl implements PegawaiRepository {
  final ApiClient _api;

  PegawaiRepositoryImpl(this._api);

  @override
  Future<List<PegawaiModel>> getAll() async {
    try {
      final data = await _api.get('/api/users') as List;
      return data
          .map((e) => PegawaiModel.fromMap(e as Map<String, dynamic>))
          .toList();
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal memuat data pegawai: ${e.toString()}');
    }
  }

  @override
  Future<PegawaiModel> getById(String id) async {
    try {
      final data = await _api.get('/api/users/$id');
      return PegawaiModel.fromMap(data as Map<String, dynamic>);
    } catch (e) {
      throw const AppException('Pegawai tidak ditemukan');
    }
  }

  @override
  Future<PegawaiModel> create({
    required String nama,
    required String email,
    required String password,
    String? jabatan,
    String? unitKerja,
    required String role,
  }) async {
    try {
      final data = await _api.post('/api/users', body: {
        'nama': nama,
        'email': email,
        'password': password,
        'jabatan': jabatan,
        'unit_kerja': unitKerja,
        'role': role,
      }) as Map<String, dynamic>;
      return PegawaiModel.fromMap(data['user'] as Map<String, dynamic>);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal menambah pegawai: ${e.toString()}');
    }
  }

  @override
  Future<PegawaiModel> update({
    required String id,
    required String nama,
    String? jabatan,
    String? unitKerja,
    required String role,
  }) async {
    try {
      final data = await _api.patch('/api/users/$id', body: {
        'nama': nama,
        'jabatan': jabatan,
        'unit_kerja': unitKerja,
        'role': role,
      });
      return PegawaiModel.fromMap(data as Map<String, dynamic>);
    } on AppException catch (e) {
      throw AppException('Gagal mengupdate pegawai: ${e.message}',
          code: e.code);
    } catch (e) {
      throw AppException('Gagal mengupdate pegawai: ${e.toString()}');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _api.delete('/api/users/$id');
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal menghapus pegawai: ${e.toString()}');
    }
  }

  @override
  Future<void> resetPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await _api.post(
        '/api/users/$userId/reset-password',
        body: {'new_password': newPassword},
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal mengubah password: ${e.toString()}');
    }
  }
}
