import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../dokumentasi/domain/dokumentasi_model.dart';
import '../../dokumentasi/presentation/dokumentasi_provider.dart';
import '../domain/rekap_upload_model.dart';

part 'rekap_upload_provider.g.dart';

/// Helper class untuk mengakumulasi data upload per user sebelum dikonversi
/// ke [RekapUploadModel].
class _UserAccumulator {
  final String userId;
  final String nama;
  final String? jabatan;
  final String? unitKerja;
  int total = 0;
  final Map<int, int> perBulan = {};

  _UserAccumulator({
    required this.userId,
    required this.nama,
    this.jabatan,
    this.unitKerja,
  });
}

@riverpod
class RekapUploadNotifier extends _$RekapUploadNotifier {
  int _selectedYear = DateTime.now().year;

  int get selectedYear => _selectedYear;

  @override
  Future<List<RekapUploadModel>> build() {
    return _fetchRekap(_selectedYear);
  }

  /// Ganti tahun yang dipilih dan muat ulang data.
  Future<void> changeYear(int year) async {
    _selectedYear = year;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchRekap(year));
  }

  /// Muat ulang data untuk tahun yang sedang dipilih.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchRekap(_selectedYear));
  }

  Future<List<RekapUploadModel>> _fetchRekap(int year) async {
    final docs = await ref.read(dokumentasiRepositoryProvider).getByYear(year);
    return _aggregate(docs);
  }

  List<RekapUploadModel> _aggregate(List<DokumentasiModel> docs) {
    final Map<String, _UserAccumulator> accMap = {};

    for (final doc in docs) {
      final acc = accMap.putIfAbsent(
        doc.userId,
        () => _UserAccumulator(
          userId: doc.userId,
          nama: doc.pegawaiNama ?? doc.userId,
          jabatan: doc.pegawaiJabatan,
          unitKerja: doc.pegawaiUnitKerja,
        ),
      );

      acc.total++;
      acc.perBulan[doc.tanggalKegiatan.month] =
          (acc.perBulan[doc.tanggalKegiatan.month] ?? 0) + 1;
    }

    final result = accMap.values
        .map(
          (acc) => RekapUploadModel(
            userId: acc.userId,
            nama: acc.nama,
            jabatan: acc.jabatan,
            unitKerja: acc.unitKerja,
            total: acc.total,
            perBulan: Map.unmodifiable(acc.perBulan),
          ),
        )
        .toList();

    result.sort((a, b) => b.total.compareTo(a.total));

    return result;
  }
}
