import 'dart:typed_data';
import '../domain/dokumentasi_model.dart';

abstract class DokumentasiRepository {
  Future<List<DokumentasiModel>> getAll({DateTime? fromDate, DateTime? toDate});
  Future<List<DokumentasiModel>> getByUserId(String userId);
  Future<DokumentasiModel> create({
    required String userId,
    required String pegawaiNama,
    required String proyek,
    required DateTime tanggalKegiatan,
    Uint8List? imageBytes,
    String? catatan,
  });
  Future<DokumentasiModel> update({
    required String id,
    required String pegawaiNama,
    required String proyek,
    required DateTime tanggalKegiatan,
    Uint8List? newImageBytes,
    String? existingImageUrl,
    String? catatan,
  });
  Future<List<DokumentasiModel>> getByYear(int year);

  /// Menyembunyikan dokumentasi (admin masih bisa melihat & mengembalikan).
  Future<void> delete(String id);

  /// Dokumentasi yang dihapus, terbaru dihapus di atas (khusus admin).
  Future<List<DokumentasiModel>> getDeleted();

  /// Mengembalikan dokumentasi yang dihapus (khusus admin).
  Future<void> restore(String id);
}
