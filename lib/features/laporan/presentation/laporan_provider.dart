import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/auth_provider.dart';
import '../data/laporan_repository.dart';
import '../data/laporan_repository_impl.dart';
import '../domain/laporan_model.dart';

part 'laporan_provider.g.dart';

@riverpod
LaporanRepository laporanRepository(Ref ref) {
  return LaporanRepositoryImpl(Supabase.instance.client);
}

/// Semua laporan (admin) dengan filter opsional
@riverpod
class AdminLaporanNotifier extends _$AdminLaporanNotifier {
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _userId;
  String? _kegiatanId;

  @override
  Future<List<LaporanModel>> build() async {
    return ref.read(laporanRepositoryProvider).getAll();
  }

  Future<void> applyFilter({
    DateTime? fromDate,
    DateTime? toDate,
    String? userId,
    String? kegiatanId,
  }) async {
    _fromDate = fromDate;
    _toDate = toDate;
    _userId = userId;
    _kegiatanId = kegiatanId;
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(laporanRepositoryProvider).getAll(
            fromDate: _fromDate,
            toDate: _toDate,
            userId: _userId,
            kegiatanId: _kegiatanId,
          ),
    );
  }
}

/// Laporan milik pegawai yang sedang login
@riverpod
Future<List<LaporanModel>> myLaporan(Ref ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return [];
  return ref.read(laporanRepositoryProvider).getByUserId(user.id);
}

/// Upload laporan baru
@riverpod
class UploadLaporanNotifier extends _$UploadLaporanNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> upload({
    required String kegiatanId,
    required Uint8List imageBytes,
    required String pegawaiNama,
    String? deskripsi,
  }) async {
    state = const AsyncLoading();
    final user = await ref.read(authStateProvider.future);
    if (user == null) {
      state = AsyncError('Tidak terautentikasi', StackTrace.current);
      return false;
    }

    final result = await AsyncValue.guard(
      () => ref.read(laporanRepositoryProvider).create(
            userId: user.id,
            kegiatanId: kegiatanId,
            imageBytes: imageBytes,
            pegawaiNama: pegawaiNama,
            deskripsi: deskripsi,
          ),
    );

    state = result.when(
      data: (_) => const AsyncData(null),
      loading: () => const AsyncLoading(),
      error: (e, s) => AsyncError(e, s),
    );

    return result.hasValue;
  }
}
