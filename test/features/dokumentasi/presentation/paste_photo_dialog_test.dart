// Test dialog "Tempel Foto". Kotak tempel aslinya elemen HTML (hanya web),
// jadi di sini yang dimuat adalah stub; yang diuji teks petunjuk dan tombol
// Batal.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/features/dokumentasi/presentation/widgets/paste_photo_dialog.dart';

void main() {
  testWidgets('menampilkan petunjuk dan Batal mengembalikan null',
      (tester) async {
    Uint8List? result = Uint8List(1);
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showPastePhotoDialog(context);
              closed = true;
            },
            child: const Text('buka'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();

    expect(find.text('Tempel Foto'), findsOneWidget);
    expect(find.textContaining('tekan lama kotak di bawah'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
    expect(find.text('Tempel Foto'), findsNothing);
  });
}
