import '../domain/pegawai_model.dart';

abstract class PegawaiRepository {
  Future<List<PegawaiModel>> getAll();
  Future<PegawaiModel> getById(String id);
  Future<PegawaiModel> create({
    required String nama,
    required String email,
    required String password,
    String? jabatan,
    String? unitKerja,
    required String role,
  });
  Future<PegawaiModel> update({
    required String id,
    required String nama,
    String? jabatan,
    String? unitKerja,
    required String role,
  });
  Future<void> delete(String id);
  Future<void> resetPassword({
    required String userId,
    required String newPassword,
  });
}
