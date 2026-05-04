import '../domain/penugasan_model.dart';

abstract class PenugasanRepository {
  Future<List<PenugasanModel>> getByKegiatanId(String kegiatanId);
  Future<void> assign({required String userId, required String kegiatanId});
  Future<void> unassign({required String userId, required String kegiatanId});
}
