import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pantau_pegawai/features/auth/presentation/auth_provider.dart';
import 'package:pantau_pegawai/features/dokumentasi/data/dokumentasi_repository.dart';
import 'package:pantau_pegawai/features/dokumentasi/domain/dokumentasi_model.dart';
import 'package:pantau_pegawai/features/dokumentasi/presentation/admin_dokumentasi_screen.dart';
import 'package:pantau_pegawai/features/dokumentasi/presentation/dokumentasi_provider.dart';
import 'package:pantau_pegawai/features/dokumentasi/presentation/dokumentasi_screen.dart';
import 'package:pantau_pegawai/features/dokumentasi/presentation/widgets/dokumentasi_search.dart';
import 'package:pantau_pegawai/features/pegawai/domain/pegawai_model.dart';
import 'package:pantau_pegawai/features/pegawai/presentation/pegawai_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

DokumentasiModel _doc(String id, String proyek, String? catatan,
        {String nama = 'Budi Santoso', int hari = 10}) =>
    DokumentasiModel(
      id: id,
      userId: 'u1',
      proyek: proyek,
      catatan: catatan,
      tanggalKegiatan: DateTime(2026, 10, hari),
      createdAt: DateTime(2026, 10, hari, 9),
      pegawaiNama: nama,
    );

final _docs = [
  _doc('1', 'Sensus Ekonomi 2026',
      'Membuat monitoring SE kondisi usaha dan keluarga yang ditemukan',
      hari: 14),
  _doc('2', 'Sakernas Tahun 2026', 'Pengawasan sakernas di Kecamatan Wori',
      nama: 'Siti Aminah', hari: 13),
  _doc('3', 'Pelayanan Statistik Terpadu', 'Menerima kunjungan DPR',
      hari: 12),
  _doc('4', 'Rapat Monitoring', null, hari: 11),
];

class _FakeRepo implements DokumentasiRepository {
  @override
  Future<List<DokumentasiModel>> getAll(
          {DateTime? fromDate, DateTime? toDate}) async =>
      _docs;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoPegawai extends PegawaiNotifier {
  @override
  Future<List<PegawaiModel>> build() async => [];
}

class _MyDocs extends MyDokumentasiNotifier {
  @override
  Future<List<DokumentasiModel>> build() async => _docs;
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dokumentasiRepositoryProvider.overrideWithValue(_FakeRepo()),
      myDokumentasiNotifierProvider.overrideWith(_MyDocs.new),
      pegawaiNotifierProvider.overrideWith(_NoPegawai.new),
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ],
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
}

Future<void> _cari(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField).first, query);
  await tester.pumpAndSettle();
}

/// Teks yang tampil, termasuk yang ditandai (semua teks dirender RichText).
Finder _teks(String text) => find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText() == text);

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('pencocokan', () {
    final kalimat = _docs.first;

    test('kalimat utuh, sebagian kata, urutan bebas, huruf besar/kecil', () {
      for (final q in [
        'Membuat monitoring SE kondisi usaha dan keluarga yang ditemukan',
        'monitoring kondisi usaha',
        'KELUARGA monitoring',
        'kondisi usa',
      ]) {
        expect(cocokPencarian(kalimat, kataPencarian(q)), isTrue, reason: q);
      }
      expect(cocokPencarian(kalimat, kataPencarian('monitoring sakernas')),
          isFalse);
    });

    test('kegiatan dan nama pegawai juga dicari; catatan kosong aman', () {
      expect(saringPencarian(_docs, 'monitoring').map((d) => d.id),
          ['1', '4']);
      expect(saringPencarian(_docs, 'siti wori').map((d) => d.id), ['2']);
      expect(saringPencarian(_docs, '   '), _docs);
    });

    test('bagian teks yang ditandai', () {
      expect(
          HighlightText.bagian(
              'Membuat monitoring SE', kataPencarian('MONITOR se')),
          [
            ('Membuat ', false),
            ('monitor', true),
            ('ing ', false),
            ('SE', true),
          ]);
    });
  });

  testWidgets('Dokumentasi Harian: cari catatan, jumlah hasil, tanpa hasil',
      (tester) async {
    await _pump(tester, const DokumentasiScreen());
    expect(find.byType(DokCard), findsNWidgets(4));

    await _cari(tester, 'monitoring SE kondisi usaha dan keluarga');
    expect(find.byType(DokCard), findsOneWidget);
    expect(find.text('1 hasil'), findsOneWidget);
    expect(
        _teks('Membuat monitoring SE kondisi usaha dan keluarga yang '
            'ditemukan'),
        findsOneWidget);

    await _cari(tester, 'tidak ada yang cocok');
    expect(find.byType(DokCard), findsNothing);
    expect(find.textContaining('Tidak ada dokumentasi yang cocok'),
        findsOneWidget);

    await tester.tap(find.byTooltip('Hapus pencarian'));
    await tester.pumpAndSettle();
    expect(find.byType(DokCard), findsNWidgets(4));
  });

  testWidgets('Riwayat Saya: cari catatan', (tester) async {
    await _pump(tester, const RiwayatDokumentasiScreen());
    await _cari(tester, 'kunjungan dpr');
    expect(find.byType(DokCard), findsOneWidget);
    expect(_teks('Menerima kunjungan DPR'), findsOneWidget);
  });

  testWidgets('Admin: cari nama dan catatan', (tester) async {
    await _pump(tester, const AdminDokumentasiScreen());
    await _cari(tester, 'siti pengawasan');
    expect(find.text('1 hasil'), findsOneWidget);
    expect(_teks('Pengawasan sakernas di Kecamatan Wori'), findsOneWidget);
    expect(_teks('Menerima kunjungan DPR'), findsNothing);
  });
}
