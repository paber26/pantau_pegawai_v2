// Setelah dokumentasi disimpan, daftar Dokumentasi Harian tidak kembali ke
// atas: data lama tetap tampil selama dimuat ulang, lalu daftar menggulir ke
// tanggal dokumentasi yang baru disimpan.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pantau_pegawai/features/auth/presentation/auth_provider.dart';
import 'package:pantau_pegawai/features/dokumentasi/data/dokumentasi_repository.dart';
import 'package:pantau_pegawai/features/dokumentasi/domain/dokumentasi_model.dart';
import 'package:pantau_pegawai/features/dokumentasi/presentation/dokumentasi_provider.dart';
import 'package:pantau_pegawai/features/dokumentasi/presentation/dokumentasi_screen.dart';
import 'package:pantau_pegawai/features/pegawai/domain/pegawai_model.dart';
import 'package:pantau_pegawai/features/pegawai/presentation/pegawai_provider.dart';
import 'package:pantau_pegawai/shared/widgets/loading_shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository palsu: [getAll] mengembalikan [docs], dan bisa ditahan dengan
/// [gate] untuk melihat tampilan selama dimuat ulang.
class _FakeRepo implements DokumentasiRepository {
  _FakeRepo(this.docs);

  List<DokumentasiModel> docs;
  Completer<void>? gate;

  @override
  Future<List<DokumentasiModel>> getAll(
      {DateTime? fromDate, DateTime? toDate}) async {
    if (gate != null) await gate!.future;
    return docs;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoPegawai extends PegawaiNotifier {
  @override
  Future<List<PegawaiModel>> build() async => [];
}

DokumentasiModel _doc(String id, DateTime tanggal) => DokumentasiModel(
      id: id,
      userId: 'u1',
      proyek: 'Kegiatan $id',
      tanggalKegiatan: tanggal,
      createdAt: tanggal,
      pegawaiNama: 'Budi',
    );

/// 100 hari ke belakang dari 12 Okt 2026, dua dokumentasi per hari,
/// urut tanggal terbaru dulu (seperti dari server).
List<DokumentasiModel> _seed() => [
      for (var d = 0; d < 100; d++)
        for (var n = 0; n < 2; n++)
          _doc('$d-$n', DateTime(2026, 10, 12).subtract(Duration(days: d))),
    ];

Future<_FakeRepo> _pumpScreen(WidgetTester tester,
    {List<DokumentasiModel>? docs}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repo = _FakeRepo(docs ?? _seed());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dokumentasiRepositoryProvider.overrideWithValue(repo),
      pegawaiNotifierProvider.overrideWith(_NoPegawai.new),
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ],
    child: const MaterialApp(home: DokumentasiScreen()),
  ));
  await tester.pumpAndSettle();
  return repo;
}

double _scrollOffset(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

/// Meniru form setelah simpan berhasil: tambah data, muat ulang, beri fokus.
void _simpan(WidgetTester tester, _FakeRepo repo, DateTime tanggal) {
  repo.docs = [...repo.docs, _doc('baru', tanggal)]
    ..sort((a, b) => b.tanggalKegiatan.compareTo(a.tanggalKegiatan));
  final container =
      ProviderScope.containerOf(tester.element(find.byType(DokumentasiScreen)));
  container.read(adminDokumentasiNotifierProvider.notifier).refresh();
  container
      .read(dokumentasiFocusNotifierProvider.notifier)
      .focus(DokumentasiFocus(tanggal: tanggal, isNew: true));
}

void _expectVisible(WidgetTester tester, String label) {
  final header = find.text(label);
  expect(header, findsOneWidget, reason: 'grup "$label" tidak dibangun');
  final rect = tester.getRect(header);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(800));
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'selama dimuat ulang daftar lama tetap tampil (tanpa shimmer), '
      'lalu daftar menuju tanggal yang disimpan', (tester) async {
    final repo = await _pumpScreen(tester);

    // Pengguna menggulir jauh ke bawah (bulan Juli).
    await tester.drag(find.byType(ListView), const Offset(0, -12000));
    await tester.pumpAndSettle();
    final before = _scrollOffset(tester);
    expect(before, greaterThan(10000));

    repo.gate = Completer<void>();
    _simpan(tester, repo, DateTime(2026, 7, 20));
    await tester.pump();

    expect(find.byType(LoadingShimmer), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(_scrollOffset(tester), before);

    repo.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    _expectVisible(tester, '20 Juli 2026');
    expect(find.text('Kegiatan baru'), findsOneWidget);
  });

  testWidgets('menuju tanggal yang jauh dari posisi sekarang (belum dibangun)',
      (tester) async {
    final repo = await _pumpScreen(tester);
    expect(_scrollOffset(tester), 0);

    _simpan(tester, repo, DateTime(2026, 7, 10));
    await tester.pumpAndSettle();

    _expectVisible(tester, '10 Juli 2026');
  });

  testWidgets('kembali ke tanggal yang lebih baru dari posisi sekarang',
      (tester) async {
    final repo = await _pumpScreen(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -20000));
    await tester.pumpAndSettle();

    _simpan(tester, repo, DateTime(2026, 9, 25));
    await tester.pumpAndSettle();

    _expectVisible(tester, '25 September 2026');
  });

  group('tombol Lompat ke tanggal', () {
    Future<void> bukaKalender(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Lompat ke tanggal'));
      await tester.pumpAndSettle();
    }

    testWidgets('pilih 20 Juli → daftar langsung menuju tanggal itu',
        (tester) async {
      await _pumpScreen(tester);
      expect(_scrollOffset(tester), 0);

      await bukaKalender(tester);
      // Kalender terbuka di bulan yang sedang dilihat (Oktober).
      expect(find.text('October 2026'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('20'));
      await tester.tap(find.text('Lompat'));
      await tester.pumpAndSettle();

      _expectVisible(tester, '20 Juli 2026');

      // Dibuka lagi: kalender langsung di bulan yang sedang dilihat (Juli).
      await bukaKalender(tester);
      expect(find.text('July 2026'), findsOneWidget);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      _expectVisible(tester, '20 Juli 2026');
    });

    testWidgets('tanggal tanpa dokumentasi tidak bisa dipilih',
        (tester) async {
      await _pumpScreen(tester, docs: [
        _doc('a', DateTime(2026, 10, 12)),
        _doc('b', DateTime(2026, 10, 10)),
      ]);

      await bukaKalender(tester);

      Finder bisaDipilih(String day) => find.ancestor(
          of: find.text(day), matching: find.byType(InkResponse));
      expect(bisaDipilih('12'), findsOneWidget);
      expect(bisaDipilih('10'), findsOneWidget);
      expect(bisaDipilih('11'), findsNothing);
      expect(bisaDipilih('9'), findsNothing);
    });
  });
}
