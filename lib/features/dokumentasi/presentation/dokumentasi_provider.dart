import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/dokumentasi_filter_store.dart';
import '../data/dokumentasi_repository.dart';
import '../data/dokumentasi_repository_impl.dart';
import '../domain/dokumentasi_model.dart';

part 'dokumentasi_provider.g.dart';

@riverpod
DokumentasiRepository dokumentasiRepository(Ref ref) {
  return DokumentasiRepositoryImpl(ref.watch(apiClientProvider));
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

  /// Memuat ulang tanpa membuang data lama, sehingga daftar tidak diganti
  /// shimmer dan posisi scroll tetap.
  Future<void> refresh() async {
    state = const AsyncLoading<List<DokumentasiModel>>().copyWithPrevious(state);
    final user = await ref.read(authStateProvider.future);
    if (user == null) return;
    state = await AsyncValue.guard(
      () => ref.read(dokumentasiRepositoryProvider).getByUserId(user.id),
    );
  }

  Future<String?> tambah({
    required String proyek,
    required DateTime tanggalKegiatan,
    Uint8List? imageBytes,
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
            imageBytes: imageBytes,
            catatan: catatan,
          );
      await refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> edit({
    required String id,
    required String proyek,
    required DateTime tanggalKegiatan,
    Uint8List? newImageBytes,
    String? existingImageUrl,
    String? catatan,
  }) async {
    try {
      final user = await ref.read(authStateProvider.future);
      if (user == null) return 'Tidak terautentikasi';

      await ref.read(dokumentasiRepositoryProvider).update(
            id: id,
            pegawaiNama: user.nama,
            proyek: proyek,
            tanggalKegiatan: tanggalKegiatan,
            newImageBytes: newImageBytes,
            existingImageUrl: existingImageUrl,
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
    // Pulihkan rentang tanggal yang tersimpan agar hasil tetap terfilter
    // setelah halaman di-refresh, bukan mengambil ulang semua data.
    final saved = await DokumentasiFilterStore.load();
    _fromDate = saved.from;
    _toDate = saved.to;
    return ref.read(dokumentasiRepositoryProvider).getAll(
          fromDate: _fromDate,
          toDate: _toDate,
        );
  }

  /// Memuat ulang tanpa membuang data lama, sehingga daftar tidak diganti
  /// shimmer dan posisi scroll tetap.
  Future<void> refresh() async {
    state = const AsyncLoading<List<DokumentasiModel>>().copyWithPrevious(state);
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

/// Dokumentasi yang dihapus pegawai/admin (khusus admin), bisa dikembalikan.
@riverpod
class DeletedDokumentasiNotifier extends _$DeletedDokumentasiNotifier {
  @override
  Future<List<DokumentasiModel>> build() {
    return ref.read(dokumentasiRepositoryProvider).getDeleted();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<DokumentasiModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(dokumentasiRepositoryProvider).getDeleted(),
    );
  }

  /// Mengembalikan dokumentasi; `null` bila berhasil, pesan error bila gagal.
  Future<String?> kembalikan(String id) async {
    try {
      await ref.read(dokumentasiRepositoryProvider).restore(id);
      await refresh();
      ref.invalidate(adminDokumentasiNotifierProvider);
      ref.invalidate(myDokumentasiNotifierProvider);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

/// Dokumentasi yang baru disimpan dari form, supaya halaman daftar langsung
/// menggulir ke tanggalnya alih-alih kembali ke atas.
class DokumentasiFocus {
  const DokumentasiFocus({required this.tanggal, required this.isNew});

  /// Tanggal kegiatan (tanpa jam).
  final DateTime tanggal;

  /// true = baru ditambahkan (di Riwayat Saya muncul paling atas).
  final bool isNew;
}

@riverpod
class DokumentasiFocusNotifier extends _$DokumentasiFocusNotifier {
  @override
  DokumentasiFocus? build() => null;

  void focus(DokumentasiFocus value) => state = value;

  void clear() => state = null;
}
