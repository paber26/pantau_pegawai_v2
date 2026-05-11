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
  Future<List<DokumentasiModel>> getByYear(int year);
  Future<void> delete(String id);
}
