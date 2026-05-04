import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/pegawai_repository.dart';
import '../data/pegawai_repository_impl.dart';
import '../domain/pegawai_model.dart';

part 'pegawai_provider.g.dart';

@riverpod
PegawaiRepository pegawaiRepository(Ref ref) {
  return PegawaiRepositoryImpl(Supabase.instance.client);
}

@riverpod
class PegawaiNotifier extends _$PegawaiNotifier {
  @override
  Future<List<PegawaiModel>> build() async {
    return ref.read(pegawaiRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(pegawaiRepositoryProvider).getAll(),
    );
  }

  Future<String?> create({
    required String nama,
    required String email,
    required String password,
    String? jabatan,
    String? unitKerja,
    required String role,
  }) async {
    try {
      await ref.read(pegawaiRepositoryProvider).create(
            nama: nama,
            email: email,
            password: password,
            jabatan: jabatan,
            unitKerja: unitKerja,
            role: role,
          );
      await refresh();
      return null; // null = sukses
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updatePegawai({
    required String id,
    required String nama,
    String? jabatan,
    String? unitKerja,
    required String role,
  }) async {
    try {
      await ref.read(pegawaiRepositoryProvider).update(
            id: id,
            nama: nama,
            jabatan: jabatan,
            unitKerja: unitKerja,
            role: role,
          );
      await refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> delete(String id) async {
    try {
      await ref.read(pegawaiRepositoryProvider).delete(id);
      await refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> resetPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await ref.read(pegawaiRepositoryProvider).resetPassword(
            userId: userId,
            newPassword: newPassword,
          );
      return null; // null = sukses
    } catch (e) {
      return e.toString(); // return pesan error
    }
  }
}
