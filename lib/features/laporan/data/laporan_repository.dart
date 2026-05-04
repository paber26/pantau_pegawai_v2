import 'dart:io';
import '../domain/laporan_model.dart';

abstract class LaporanRepository {
  Future<List<LaporanModel>> getAll({
    DateTime? fromDate,
    DateTime? toDate,
    String? userId,
    String? kegiatanId,
  });
  Future<List<LaporanModel>> getByUserId(String userId);
  Future<LaporanModel> getById(String id);
  Future<LaporanModel> create({
    required String userId,
    required String kegiatanId,
    required File imageFile,
    required String pegawaiNama,
    String? deskripsi,
  });
}
