import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
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
      final response = await http.post(
        Uri.parse(SupabaseConstants.adminResetPasswordUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': SupabaseConstants.anonKey,
        },
        body: jsonEncode({
          'user_id': userId,
          'new_password': newPassword,
        }),
      );

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final errMsg = data['error'] as String? ??
            'Error ${response.statusCode}: Gagal mengubah password';
        throw AppException(errMsg);
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Gagal mengubah password: ${e.toString()}');
    }
  }
}
