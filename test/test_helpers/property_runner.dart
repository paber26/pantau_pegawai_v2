// Helper sederhana untuk menjalankan property-based test menggunakan
// `flutter_test` saja. Iterasi dilakukan secara manual dengan `Random`
// yang di-seed agar reproducible.
//
// Pemakaian:
//   runProperty('valid headers preserve bytes', (random, i) {
//     final input = generateValidImage(random);
//     final result = ClipboardImageSuccess(input);
//     expect(result.imageBytes, input);
//   });
//
// Iterasi default 100x; bisa di-override per panggilan untuk operasi
// yang mahal (mis. encode/decode gambar).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Menjalankan blok [check] sebanyak [iterations] kali dengan
/// `Random` yang di-seed [seed]. Bila [check] melempar error pada
/// salah satu iterasi, test gagal dengan informasi seed dan iterasi
/// agar mudah direproduksi.
void runProperty(
  String name,
  void Function(Random random, int iteration) check, {
  int iterations = 100,
  int seed = 42,
}) {
  test(name, () {
    final random = Random(seed);
    for (int i = 0; i < iterations; i++) {
      try {
        check(random, i);
      } catch (e, st) {
        fail(
          'Property failed at iteration $i (seed=$seed):\n$e\n$st',
        );
      }
    }
  });
}

/// Versi async dari [runProperty]. Digunakan oleh test yang memanggil
/// API asynchronous (mis. `ImageCompressor.compress`).
void runPropertyAsync(
  String name,
  Future<void> Function(Random random, int iteration) check, {
  int iterations = 100,
  int seed = 42,
  Duration? timeout,
}) {
  test(
    name,
    () async {
      final random = Random(seed);
      for (int i = 0; i < iterations; i++) {
        try {
          await check(random, i);
        } catch (e, st) {
          fail(
            'Property failed at iteration $i (seed=$seed):\n$e\n$st',
          );
        }
      }
    },
    timeout: timeout != null ? Timeout(timeout) : null,
  );
}
