import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/features/dokumentasi/domain/dokumentasi_model.dart';

// ---------------------------------------------------------------------------
// Helper factory
// ---------------------------------------------------------------------------

DokumentasiModel _makeDok({
  String id = 'id1',
  String userId = 'user1',
  String proyek = 'Test Proyek',
  DateTime? tanggal,
  String? pegawaiNama,
  String? pegawaiJabatan,
  String? pegawaiUnitKerja,
}) =>
    DokumentasiModel(
      id: id,
      userId: userId,
      proyek: proyek,
      tanggalKegiatan: tanggal ?? DateTime(2026, 1, 15),
      createdAt: DateTime(2026, 1, 15),
      pegawaiNama: pegawaiNama,
      pegawaiJabatan: pegawaiJabatan,
      pegawaiUnitKerja: pegawaiUnitKerja,
    );

// ---------------------------------------------------------------------------
// Helper filter functions (replicating production logic from DokumentasiScreen)
// ---------------------------------------------------------------------------

/// Replikasi logika filter userId dari DokumentasiScreen.
List<DokumentasiModel> filterByUserId(
        List<DokumentasiModel> list, String userId) =>
    list.where((d) => d.userId == userId).toList();

/// Replikasi logika filter proyek dari DokumentasiScreen (case-insensitive contains).
List<DokumentasiModel> filterByProyek(
        List<DokumentasiModel> list, String filterText) =>
    list
        .where((d) => d.proyek.toLowerCase().contains(filterText.toLowerCase()))
        .toList();

/// Replikasi logika filter tanggal dari DokumentasiScreen (inklusif kedua batas).
List<DokumentasiModel> filterByDateRange(
        List<DokumentasiModel> list, DateTime from, DateTime to) =>
    list
        .where((d) =>
            !d.tanggalKegiatan.isBefore(from) && !d.tanggalKegiatan.isAfter(to))
        .toList();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Filter DokumentasiScreen', () {
    // 14.1 — filter by userId
    test(
        'filter userId hanya menampilkan dokumentasi milik userId yang dipilih',
        () {
      final list = [
        _makeDok(id: '1', userId: 'user1'),
        _makeDok(id: '2', userId: 'user2'),
        _makeDok(id: '3', userId: 'user1'),
      ];
      final result = filterByUserId(list, 'user1');
      expect(result.length, 2);
      expect(result.every((d) => d.userId == 'user1'), isTrue);
    });

    test('filter userId dengan userId yang tidak ada menghasilkan list kosong',
        () {
      final list = [
        _makeDok(id: '1', userId: 'user1'),
        _makeDok(id: '2', userId: 'user2'),
      ];
      final result = filterByUserId(list, 'user99');
      expect(result, isEmpty);
    });

    // 14.2 — Property test filter proyek
    test(
        'filter proyek hanya menampilkan dokumentasi yang proyeknya mengandung teks filter',
        () {
      // Test dengan berbagai kombinasi
      final testCases = [
        ('survei', ['Survei Harga', 'survei ekonomi', 'SURVEI SOSIAL']),
        ('BPS', ['BPS Pusat', 'Kegiatan BPS']),
        ('rapat', ['Rapat Koordinasi', 'RAPAT BULANAN']),
      ];

      for (final (filter, expectedProyek) in testCases) {
        final list = [
          ...expectedProyek.map((p) => _makeDok(proyek: p)),
          _makeDok(proyek: 'Tidak Relevan'),
          _makeDok(proyek: 'Kegiatan Lain'),
        ];
        final result = filterByProyek(list, filter);
        expect(
          result.every(
              (d) => d.proyek.toLowerCase().contains(filter.toLowerCase())),
          isTrue,
          reason:
              'Filter "$filter" harus hanya menampilkan proyek yang mengandung teks tersebut',
        );
        // Pastikan semua proyek yang seharusnya muncul memang muncul
        expect(
          result.length,
          expectedProyek.length,
          reason:
              'Filter "$filter" harus menampilkan ${expectedProyek.length} item',
        );
      }
    });

    test('filter proyek dengan string kosong menampilkan semua dokumentasi',
        () {
      final list = [
        _makeDok(id: '1', proyek: 'Proyek A'),
        _makeDok(id: '2', proyek: 'Proyek B'),
      ];
      final result = filterByProyek(list, '');
      expect(result.length, 2);
    });

    // 14.3 — Property test filter tanggal
    test(
        'filter tanggal hanya menampilkan dokumentasi dalam rentang yang dipilih',
        () {
      final from = DateTime(2026, 3, 1);
      final to = DateTime(2026, 5, 31);
      final list = [
        _makeDok(id: '1', tanggal: DateTime(2026, 1, 15)), // di luar
        _makeDok(id: '2', tanggal: DateTime(2026, 3, 1)), // batas bawah
        _makeDok(id: '3', tanggal: DateTime(2026, 4, 15)), // di dalam
        _makeDok(id: '4', tanggal: DateTime(2026, 5, 31)), // batas atas
        _makeDok(id: '5', tanggal: DateTime(2026, 6, 1)), // di luar
      ];
      final result = filterByDateRange(list, from, to);
      expect(result.length, 3);
      expect(
        result.every((d) =>
            !d.tanggalKegiatan.isBefore(from) &&
            !d.tanggalKegiatan.isAfter(to)),
        isTrue,
      );
    });

    test(
        'filter tanggal dengan rentang yang tidak ada data menghasilkan kosong',
        () {
      final list = [
        _makeDok(id: '1', tanggal: DateTime(2026, 1, 15)),
        _makeDok(id: '2', tanggal: DateTime(2026, 2, 20)),
      ];
      final result =
          filterByDateRange(list, DateTime(2026, 6, 1), DateTime(2026, 12, 31));
      expect(result, isEmpty);
    });

    test('filter tanggal inklusif pada batas bawah dan atas', () {
      final from = DateTime(2026, 1, 1);
      final to = DateTime(2026, 12, 31);
      final list = [
        _makeDok(id: '1', tanggal: DateTime(2026, 1, 1)), // tepat batas bawah
        _makeDok(id: '2', tanggal: DateTime(2026, 12, 31)), // tepat batas atas
      ];
      final result = filterByDateRange(list, from, to);
      expect(result.length, 2);
    });
  });
}
