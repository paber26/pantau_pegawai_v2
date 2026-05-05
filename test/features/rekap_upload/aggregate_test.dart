import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/features/dokumentasi/domain/dokumentasi_model.dart';
import 'package:pantau_pegawai/features/rekap_upload/domain/rekap_upload_model.dart';

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
// Helper aggregation function (replicating _aggregate from RekapUploadNotifier)
// ---------------------------------------------------------------------------

/// Replikasi logika `_aggregate` dari `RekapUploadNotifier`.
/// Group by userId, hitung total dan perBulan, sort descending by total.
List<RekapUploadModel> aggregateRekap(List<DokumentasiModel> docs) {
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

/// Helper accumulator class (mirrors the private class in production code).
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('aggregateRekap', () {
    // 14.4 — aggregate list kosong
    test('aggregate list kosong menghasilkan list kosong', () {
      final result = aggregateRekap([]);
      expect(result, isEmpty);
    });

    // 14.5 — aggregate satu user beberapa bulan
    test('aggregate satu user beberapa dokumentasi di bulan berbeda', () {
      final docs = [
        _makeDok(
            userId: 'u1', tanggal: DateTime(2026, 1, 10), pegawaiNama: 'Budi'),
        _makeDok(
            userId: 'u1', tanggal: DateTime(2026, 1, 20), pegawaiNama: 'Budi'),
        _makeDok(
            userId: 'u1', tanggal: DateTime(2026, 3, 5), pegawaiNama: 'Budi'),
      ];
      final result = aggregateRekap(docs);
      expect(result.length, 1);
      expect(result[0].total, 3);
      expect(result[0].perBulan[1], 2); // Januari: 2
      expect(result[0].perBulan[3], 1); // Maret: 1
    });

    test('aggregate satu user satu bulan', () {
      final docs = [
        _makeDok(
            userId: 'u1', tanggal: DateTime(2026, 6, 1), pegawaiNama: 'Ani'),
        _makeDok(
            userId: 'u1', tanggal: DateTime(2026, 6, 15), pegawaiNama: 'Ani'),
      ];
      final result = aggregateRekap(docs);
      expect(result.length, 1);
      expect(result[0].total, 2);
      expect(result[0].perBulan[6], 2);
      expect(result[0].nama, 'Ani');
    });

    // 14.6 — aggregate beberapa user diurutkan descending
    test('aggregate beberapa user diurutkan descending berdasarkan total', () {
      final docs = [
        _makeDok(id: '1', userId: 'u1', pegawaiNama: 'Andi'),
        _makeDok(id: '2', userId: 'u2', pegawaiNama: 'Budi'),
        _makeDok(id: '3', userId: 'u2', pegawaiNama: 'Budi'),
        _makeDok(id: '4', userId: 'u3', pegawaiNama: 'Cici'),
        _makeDok(id: '5', userId: 'u3', pegawaiNama: 'Cici'),
        _makeDok(id: '6', userId: 'u3', pegawaiNama: 'Cici'),
      ];
      final result = aggregateRekap(docs);
      expect(result.length, 3);
      expect(result[0].total >= result[1].total, isTrue);
      expect(result[1].total >= result[2].total, isTrue);
      // Cici (3) > Budi (2) > Andi (1)
      expect(result[0].nama, 'Cici');
      expect(result[1].nama, 'Budi');
      expect(result[2].nama, 'Andi');
    });

    // 14.7 — Property test: grand total dan per-bulan consistency
    test('grand total sama dengan jumlah semua individual total', () {
      // Test dengan berbagai ukuran list
      for (final count in [0, 1, 5, 20, 50]) {
        final docs = List.generate(
          count,
          (i) => _makeDok(
            id: 'id$i',
            userId: 'user${i % 3}',
            tanggal: DateTime(2026, (i % 12) + 1, 1),
            pegawaiNama: 'User ${i % 3}',
          ),
        );
        final result = aggregateRekap(docs);
        final grandTotal = result.fold<int>(0, (sum, r) => sum + r.total);
        expect(
          grandTotal,
          docs.length,
          reason: 'Grand total harus sama dengan jumlah dokumen (count=$count)',
        );

        // Property 8: sum(perBulan.values) == total untuk setiap item
        for (final rekap in result) {
          final sumPerBulan =
              rekap.perBulan.values.fold<int>(0, (s, v) => s + v);
          expect(
            sumPerBulan,
            rekap.total,
            reason:
                'Sum perBulan harus sama dengan total untuk ${rekap.nama} (count=$count)',
          );
        }
      }
    });

    // 14.8 — Property test: urutan descending
    test('daftar rekap selalu diurutkan descending berdasarkan total', () {
      for (final count in [0, 1, 2, 10]) {
        final docs = List.generate(
          count,
          (i) => _makeDok(
            id: 'id$i',
            userId: 'user${i % 5}',
            tanggal: DateTime(2026, (i % 12) + 1, 1),
            pegawaiNama: 'User ${i % 5}',
          ),
        );
        final result = aggregateRekap(docs);
        for (int i = 0; i < result.length - 1; i++) {
          expect(
            result[i].total >= result[i + 1].total,
            isTrue,
            reason:
                'result[$i].total (${result[i].total}) harus >= result[${i + 1}].total (${result[i + 1].total})',
          );
        }
      }
    });

    test('aggregate menggunakan userId sebagai nama jika pegawaiNama null', () {
      final docs = [
        _makeDok(userId: 'user-abc', pegawaiNama: null),
      ];
      final result = aggregateRekap(docs);
      expect(result.length, 1);
      expect(result[0].nama, 'user-abc');
    });

    test('aggregate menyimpan jabatan dan unitKerja dari dokumen pertama', () {
      final docs = [
        _makeDok(
          userId: 'u1',
          pegawaiNama: 'Dedi',
          pegawaiJabatan: 'Statistisi',
          pegawaiUnitKerja: 'BPS Kota',
        ),
        _makeDok(
          id: 'id2',
          userId: 'u1',
          pegawaiNama: 'Dedi',
          pegawaiJabatan: 'Statistisi',
          pegawaiUnitKerja: 'BPS Kota',
        ),
      ];
      final result = aggregateRekap(docs);
      expect(result.length, 1);
      expect(result[0].jabatan, 'Statistisi');
      expect(result[0].unitKerja, 'BPS Kota');
      expect(result[0].total, 2);
    });
  });
}
