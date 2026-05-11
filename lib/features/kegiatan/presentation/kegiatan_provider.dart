import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/kegiatan_repository.dart';
import '../data/kegiatan_repository_impl.dart';
import '../domain/bulk_import_result.dart';
import '../domain/kegiatan_model.dart';
import '../domain/proyek_constants.dart';

part 'kegiatan_provider.g.dart';

@riverpod
KegiatanRepository kegiatanRepository(Ref ref) {
  return KegiatanRepositoryImpl(Supabase.instance.client);
}

/// Semua kegiatan (untuk admin)
@riverpod
class KegiatanNotifier extends _$KegiatanNotifier {
  @override
  Future<List<KegiatanModel>> build() async {
    return ref.read(kegiatanRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(kegiatanRepositoryProvider).getAll(),
    );
  }

  Future<bool> create({
    required String judul,
    String? deskripsi,
    required DateTime deadline,
  }) async {
    try {
      await ref.read(kegiatanRepositoryProvider).create(
            judul: judul,
            deskripsi: deskripsi,
            deadline: deadline,
          );
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateKegiatan({
    required String id,
    required String judul,
    String? deskripsi,
    required DateTime deadline,
  }) async {
    try {
      await ref.read(kegiatanRepositoryProvider).update(
            id: id,
            judul: judul,
            deskripsi: deskripsi,
            deadline: deadline,
          );
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await ref.read(kegiatanRepositoryProvider).delete(id);
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<BulkImportResult?> bulkImport() async {
    try {
      final result = await ref
          .read(kegiatanRepositoryProvider)
          .bulkImport(kProyekBulkImport, DateTime(2026, 12, 31));
      await refresh();
      return result;
    } catch (_) {
      return null;
    }
  }
}

/// Kegiatan milik pegawai yang sedang login
@riverpod
Future<List<KegiatanModel>> myKegiatan(Ref ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return ref.read(kegiatanRepositoryProvider).getByUserId(user.id);
}

/// Daftar semua kegiatan/proyek untuk dropdown di form dokumentasi
/// Terpisah dari KegiatanNotifier agar pegawai tidak memicu state management admin
@riverpod
Future<List<KegiatanModel>> kegiatanList(Ref ref) async {
  return ref.read(kegiatanRepositoryProvider).getAll();
}
