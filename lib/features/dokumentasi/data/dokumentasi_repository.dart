import 'dart:io';
import '../domain/dokumentasi_model.dart';

abstract class DokumentasiRepository {
  Future<List<DokumentasiModel>> getAll({DateTime? fromDate, DateTime? toDate});
  Future<List<DokumentasiModel>> getByUserId(String userId);
  Future<DokumentasiModel> create({
    required String userId,
    required String pegawaiNama,
    required String proyek,
    required DateTime tanggalKegiatan,
    File? imageFile,
    List<int>? imageBytes, // untuk Flutter Web
    String? catatan,
    String? link,
  });
  Future<List<DokumentasiModel>> getByYear(int year);
  Future<void> delete(String id);
}
