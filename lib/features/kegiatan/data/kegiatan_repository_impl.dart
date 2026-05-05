import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/kegiatan_model.dart';
import 'kegiatan_repository.dart';

class KegiatanRepositoryImpl implements KegiatanRepository {
  final SupabaseClient _client;

  KegiatanRepositoryImpl(this._client);

  @override
  Future<List<KegiatanModel>> getAll() async {
    try {
      final data = await _client
          .from('kegiatan')
          .select()
          .order('deadline', ascending: true);
      return (data as List).map((e) => KegiatanModel.fromMap(e)).toList();
    } catch (e) {
      throw AppException('Gagal memuat kegiatan: ${e.toString()}');
    }
  }

  @override
  Future<List<KegiatanModel>> getByUserId(String userId) async {
    try {
      final data = await _client
          .from('penugasan')
          .select('kegiatan(*)')
          .eq('user_id', userId);
      return (data as List)
          .map((e) =>
              KegiatanModel.fromMap(e['kegiatan'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException('Gagal memuat kegiatan: ${e.toString()}');
    }
  }

  @override
  Future<KegiatanModel> getById(String id) async {
    try {
      final data =
          await _client.from('kegiatan').select().eq('id', id).single();
      return KegiatanModel.fromMap(data);
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
      final data = await _client
          .from('kegiatan')
          .insert({
            'judul': judul,
            'deskripsi': deskripsi,
            'deadline': deadline.toIso8601String().split('T').first,
          })
          .select()
          .single();
      return KegiatanModel.fromMap(data);
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
      final data = await _client
          .from('kegiatan')
          .update({
            'judul': judul,
            'deskripsi': deskripsi,
            'deadline': deadline.toIso8601String().split('T').first,
          })
          .eq('id', id)
          .select()
          .single();
      return KegiatanModel.fromMap(data);
    } catch (e) {
      throw AppException('Gagal mengupdate kegiatan: ${e.toString()}');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('kegiatan').delete().eq('id', id);
    } catch (e) {
      throw AppException('Gagal menghapus kegiatan: ${e.toString()}');
    }
  }
}
