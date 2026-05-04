import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/penugasan_model.dart';
import 'penugasan_repository.dart';

class PenugasanRepositoryImpl implements PenugasanRepository {
  final SupabaseClient _client;

  PenugasanRepositoryImpl(this._client);

  @override
  Future<List<PenugasanModel>> getByKegiatanId(String kegiatanId) async {
    try {
      final data = await _client
          .from('penugasan')
          .select('*, users(*)')
          .eq('kegiatan_id', kegiatanId);
      return (data as List).map((e) => PenugasanModel.fromMap(e)).toList();
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
      await _client.from('penugasan').insert({
        'user_id': userId,
        'kegiatan_id': kegiatanId,
      });
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
      await _client
          .from('penugasan')
          .delete()
          .eq('user_id', userId)
          .eq('kegiatan_id', kegiatanId);
    } catch (e) {
      throw AppException('Gagal unassign pegawai: ${e.toString()}');
    }
  }
}
