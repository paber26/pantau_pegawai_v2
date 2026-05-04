import '../domain/kegiatan_model.dart';

abstract class KegiatanRepository {
  Future<List<KegiatanModel>> getAll();
  Future<List<KegiatanModel>> getByUserId(String userId);
  Future<KegiatanModel> getById(String id);
  Future<KegiatanModel> create({
    required String judul,
    String? deskripsi,
    required DateTime deadline,
  });
  Future<KegiatanModel> update({
    required String id,
    required String judul,
    String? deskripsi,
    required DateTime deadline,
  });
  Future<void> delete(String id);
}
