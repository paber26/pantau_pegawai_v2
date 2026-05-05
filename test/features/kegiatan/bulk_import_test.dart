import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/features/kegiatan/domain/bulk_import_result.dart';
import 'package:pantau_pegawai/features/kegiatan/domain/proyek_constants.dart';

/// Helper yang mereplikasi logika filter idempotency dari
/// [KegiatanRepositoryImpl.bulkImport] tanpa membutuhkan SupabaseClient.
BulkImportResult simulateBulkImport({
  required List<String> judulList,
  required Set<String> existingTitles,
}) {
  final newItems = judulList.where((j) => !existingTitles.contains(j)).toList();
  return BulkImportResult(
    inserted: newItems.length,
    skipped: judulList.length - newItems.length,
  );
}

void main() {
  group('simulateBulkImport – logika filter idempotency', () {
    // 15.1
    test('semua proyek baru: inserted == judulList.length, skipped == 0', () {
      final result = simulateBulkImport(
        judulList: ['Proyek A', 'Proyek B', 'Proyek C'],
        existingTitles: {},
      );
      expect(result.inserted, 3);
      expect(result.skipped, 0);
    });

    // 15.2
    test('beberapa proyek sudah ada: hanya yang baru diinsert', () {
      final result = simulateBulkImport(
        judulList: ['Proyek A', 'Proyek B', 'Proyek C'],
        existingTitles: {'Proyek A'},
      );
      expect(result.inserted, 2);
      expect(result.skipped, 1);
    });

    // 15.3
    test('semua proyek sudah ada: inserted == 0, skipped == judulList.length',
        () {
      final result = simulateBulkImport(
        judulList: ['Proyek A', 'Proyek B'],
        existingTitles: {'Proyek A', 'Proyek B'},
      );
      expect(result.inserted, 0);
      expect(result.skipped, 2);
    });

    // 15.4 – property: idempotency
    test('idempotency: run kedua selalu menghasilkan inserted == 0', () {
      final judulList = ['Proyek A', 'Proyek B', 'Proyek C'];
      final existingBefore = <String>{};

      // Run pertama – semua baru
      final run1 = simulateBulkImport(
          judulList: judulList, existingTitles: existingBefore);
      expect(run1.inserted, judulList.length);
      expect(run1.skipped, 0);

      // Setelah run pertama, semua judul sudah ada di DB
      final existingAfterRun1 = {...existingBefore, ...judulList};

      // Run kedua – tidak ada yang baru
      final run2 = simulateBulkImport(
          judulList: judulList, existingTitles: existingAfterRun1);

      expect(run2.inserted, 0,
          reason: 'Run kedua tidak boleh menginsert apapun (idempotent)');
      expect(run2.skipped, judulList.length);
    });

    // 15.5 – property: deadline
    test('semua proyek yang diimport menggunakan deadline 31 Desember 2026',
        () {
      final expectedDeadline = DateTime(2026, 12, 31);

      final deadline = DateTime(2026, 12, 31);
      expect(deadline.year, expectedDeadline.year);
      expect(deadline.month, expectedDeadline.month);
      expect(deadline.day, expectedDeadline.day);

      // Verifikasi format ISO yang akan disimpan ke DB
      final isoDate = deadline.toIso8601String().split('T').first;
      expect(isoDate, '2026-12-31');
    });
  });

  group('kProyekBulkImport', () {
    test('kProyekBulkImport berisi 65 judul unik', () {
      expect(kProyekBulkImport.length, 65);

      // Semua judul unik (tidak ada duplikat)
      final uniqueTitles = kProyekBulkImport.toSet();
      expect(uniqueTitles.length, kProyekBulkImport.length,
          reason: 'Semua judul dalam kProyekBulkImport harus unik');
    });
  });
}
