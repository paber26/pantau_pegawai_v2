import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/pegawai_model.dart';
import 'pegawai_repository.dart';

class PegawaiRepositoryImpl implements PegawaiRepository {
  final SupabaseClient _client;

  PegawaiRepositoryImpl(this._client);

  @override
  Future<List<PegawaiModel>> getAll() async {
    try {
      final data =
          await _client.from('users').select().order('nama', ascending: true);
      return (data as List).map((e) => PegawaiModel.fromMap(e)).toList();
    } catch (e) {
      throw AppException('Gagal memuat data pegawai: ${e.toString()}');
    }
  }

  @override
  Future<PegawaiModel> getById(String id) async {
    try {
      final data = await _client.from('users').select().eq('id', id).single();
      return PegawaiModel.fromMap(data);
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
      final session = _client.auth.currentSession;
      if (session == null) throw const AppException('Sesi tidak valid');

      final response = await _client.functions.invoke(
        'admin-create-user',
        body: {
          'nama': nama,
          'email': email,
          'password': password,
          'jabatan': jabatan,
          'unit_kerja': unitKerja,
          'role': role,
        },
      );

      final dynamic rawData = response.data;
      Map<String, dynamic>? data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      }

      if (response.status != 200) {
        final errMsg = data?['error'] as String? ?? 'Gagal menambah pegawai';
        throw AppException(errMsg);
      }

      return PegawaiModel.fromMap(data!['user'] as Map<String, dynamic>);
    } on AppException {
      rethrow;
    } on FunctionException catch (e) {
      throw AppException('Edge Function error: ${e.details}');
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
      final data = await _client
          .from('users')
          .update({
            'nama': nama,
            'jabatan': jabatan,
            'unit_kerja': unitKerja,
            'role': role,
          })
          .eq('id', id)
          .select()
          .single();
      return PegawaiModel.fromMap(data);
    } catch (e) {
      throw AppException('Gagal mengupdate pegawai: ${e.toString()}');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) throw const AppException('Sesi tidak valid');

      final response = await _client.functions.invoke(
        'admin-delete-user',
        body: {'user_id': id},
      );

      if (response.status != 200) {
        final dynamic rawData = response.data;
        final errMsg = (rawData is Map ? rawData['error'] : null) as String? ??
            'Gagal menghapus pegawai';
        throw AppException(errMsg);
      }
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
    final session = _client.auth.currentSession;
    if (session == null) throw const AppException('Sesi tidak valid');

    try {
      final response = await _client.functions.invoke(
        'admin-reset-password',
        body: {
          'user_id': userId,
          'new_password': newPassword,
        },
      );

      // response.data bisa berupa Map atau String tergantung content-type
      final dynamic rawData = response.data;
      Map<String, dynamic>? data;
      if (rawData is Map<String, dynamic>) {
        data = rawData;
      } else if (rawData is String) {
        try {
          data = Map<String, dynamic>.from(
            (rawData.isNotEmpty ? rawData : '{}') as dynamic,
          );
        } catch (_) {
          data = null;
        }
      }

      if (response.status != 200) {
        final errMsg = data?['error'] as String? ??
            'Error ${response.status}: Gagal mengubah password';
        throw AppException(errMsg);
      }
    } on AppException {
      rethrow;
    } on FunctionException catch (e) {
      throw AppException('Edge Function error: ${e.details}');
    } catch (e) {
      throw AppException('Gagal mengubah password: ${e.toString()}');
    }
  }
}
