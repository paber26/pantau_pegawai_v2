import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/dokumentasi_repository.dart';
import '../data/dokumentasi_repository_impl.dart';
import '../domain/dokumentasi_model.dart';

part 'dokumentasi_provider.g.dart';

@riverpod
DokumentasiRepository dokumentasiRepository(Ref ref) {
  return DokumentasiRepositoryImpl(Supabase.instance.client);
}

/// Dokumentasi milik pegawai yang login
@riverpod
class MyDokumentasiNotifier extends _$MyDokumentasiNotifier {
  @override
  Future<List<DokumentasiModel>> build() async {
    final user = await ref.watch(authStateProvider.future);
    if (user == null) return [];
    return ref.read(dokumentasiRepositoryProvider).getByUserId(user.id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final user = await ref.read(authStateProvider.future);
    if (user == null) return;
    state = await AsyncValue.guard(
      () => ref.read(dokumentasiRepositoryProvider).getByUserId(user.id),
    );
  }

  Future<String?> tambah({
    required String proyek,
    required DateTime tanggalKegiatan,
    File? imageFile,
    Uint8List? imageBytes, // untuk Flutter Web
    String? catatan,
  }) async {
    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) return 'Tidak terautentikasi';

      await ref.read(dokumentasiRepositoryProvider).create(
            userId: user.id,
            pegawaiNama: user.nama,
            proyek: proyek,
            tanggalKegiatan: tanggalKegiatan,
            imageFile: imageFile,
            imageBytes: imageBytes,
            catatan: catatan,
          );
      await refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> hapus(String id) async {
    try {
      await ref.read(dokumentasiRepositoryProvider).delete(id);
      await refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

/// Semua dokumentasi untuk admin
@riverpod
class AdminDokumentasiNotifier extends _$AdminDokumentasiNotifier {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  Future<List<DokumentasiModel>> build() async {
    return ref.read(dokumentasiRepositoryProvider).getAll();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(dokumentasiRepositoryProvider).getAll(
            fromDate: _fromDate,
            toDate: _toDate,
          ),
    );
  }

  Future<void> applyFilter({DateTime? fromDate, DateTime? toDate}) async {
    _fromDate = fromDate;
    _toDate = toDate;
    await refresh();
  }
}
