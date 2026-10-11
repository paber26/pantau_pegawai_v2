import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/shared/widgets/photo_viewer.dart';

/// Membuka [PhotoViewer] berisi "foto" 200x100 di tengah layar 400x800.
Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDialog<void>(
          context: context,
          useSafeArea: false,
          builder: (_) => const PhotoViewer(
            child: SizedBox(
              key: ValueKey('foto'),
              width: 200,
              height: 100,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
        child: const Text('buka'),
      ),
    ),
  ));
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
  expect(find.byType(PhotoViewer), findsOneWidget);
}

void main() {
  testWidgets('layar penuh tanpa sudut membulat', (tester) async {
    await _open(tester);
    expect(tester.getSize(find.byType(PhotoViewer)), const Size(400, 800));
    expect(tester.getCenter(find.byKey(const ValueKey('foto'))),
        const Offset(200, 400));
  });

  testWidgets('tombol Tutup menutup', (tester) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets('ketuk foto tidak menutup, ketuk area hitam menutup',
      (tester) async {
    await _open(tester);

    await tester.tapAt(const Offset(200, 400)); // tengah foto
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsOneWidget);

    await tester.tapAt(const Offset(200, 650)); // di bawah foto
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets('geser foto ke bawah menutup', (tester) async {
    await _open(tester);
    await tester.drag(find.byKey(const ValueKey('foto')), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsNothing);
  });
}
