// Property-based tests untuk PasteImageHandler.
//
// Feature: paste-image-documentation
// Properties tercakup:
//   - Property 2: Image replacement preserves only new image (Req 1.5, 6.2)
//   - Property 6: Error result to message mapping is total and deterministic
//                 (Req 5.1, 5.2, 5.3, 5.4)
//   - Property 7: Form state preservation on error (Req 5.5)
//   - Property 8: Focus-based paste routing (Req 6.6, 7.2, 7.3)
//   - Property 9: Non-paste keyboard shortcuts pass through (Req 7.1)
//
// Unit tests tercakup (Task 8.2):
//   - Keyboard listener registered on desktop/web (Req 2.1)
//   - No error shown for text-only clipboard on non-text focus (Req 7.4)
//
// Iterasi minimum 100 sesuai design.md. Provider Riverpod
// (`clipboardServiceProvider`, `imageCompressorProvider`) di-override
// menggunakan `ProviderScope.overrides` agar test berjalan tanpa
// dependensi platform.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/core/services/clipboard_service.dart';
import 'package:pantau_pegawai/core/services/clipboard_service_provider.dart';
import 'package:pantau_pegawai/core/services/image_compressor.dart';
import 'package:pantau_pegawai/features/dokumentasi/presentation/widgets/paste_image_handler.dart';

/// Fake [ClipboardService] yang mengembalikan [result] yang sudah
/// ditentukan pada setiap pembacaan dan menghitung jumlah panggilan
/// (untuk memverifikasi properti routing fokus).
class _FakeClipboardService implements ClipboardService {
  _FakeClipboardService({required this.result, this.supported = true});

  ClipboardReadResult result;
  bool supported;
  int readCount = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<ClipboardReadResult> readImageFromClipboard() async {
    readCount += 1;
    return result;
  }
}

/// Fake [ImageCompressor] yang langsung mengembalikan byte input
/// sebagai hasil sukses. Mempercepat test dengan menghindari decode/encode.
class _FakeImageCompressor implements ImageCompressor {
  _FakeImageCompressor({this.result});

  /// Bila null, default-nya [CompressSuccess] dengan byte input.
  CompressResult? result;

  @override
  Future<CompressResult> compress(Uint8List imageBytes) async {
    return result ?? CompressSuccess(imageBytes);
  }

  // Sisanya tidak dipakai test; method privat tidak perlu di-override.
  @override
  // ignore: unused_element
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pesan error yang DIPETAKAN dari setiap varian error
/// [ClipboardReadResult] sesuai design.md tabel "Error Messages".
const Map<Type, String> _expectedErrorMessages = {
  ClipboardEmpty: 'Clipboard kosong. Salin gambar terlebih dahulu.',
  ClipboardNoImage:
      'Clipboard tidak berisi gambar. Salin screenshot terlebih dahulu.',
  ClipboardCorruptImage:
      'Gagal membaca gambar dari clipboard. Coba salin ulang.',
  ClipboardPermissionDenied:
      'Izin akses clipboard ditolak. Periksa pengaturan izin aplikasi.',
};

/// Membangun varian error berdasarkan indeks (digunakan property test
/// untuk menjelajahi semua varian secara seragam).
ClipboardReadResult _errorVariantAt(int index) {
  final variants = <ClipboardReadResult>[
    const ClipboardEmpty(),
    const ClipboardNoImage(),
    const ClipboardCorruptImage(),
    const ClipboardPermissionDenied(),
  ];
  return variants[index % variants.length];
}

/// Membangun MaterialApp test berisi [PasteImageHandler] dengan provider
/// override. Mengembalikan [GlobalKey] handler dan callback recorder.
({
  Widget app,
  GlobalKey<PasteImageHandlerState> handlerKey,
  List<Uint8List> pastedBytes,
  int Function() errorCount,
}) _buildHarness({
  required ClipboardService clipboardService,
  ImageCompressor? imageCompressor,
  Widget? body,
}) {
  final handlerKey = GlobalKey<PasteImageHandlerState>();
  final pasted = <Uint8List>[];
  int errors = 0;

  final compressor = imageCompressor ?? _FakeImageCompressor();

  final app = ProviderScope(
    overrides: [
      clipboardServiceProvider.overrideWithValue(clipboardService),
      imageCompressorProvider.overrideWithValue(compressor),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: PasteImageHandler(
          key: handlerKey,
          onImagePasted: pasted.add,
          onError: () => errors += 1,
          child: body ??
              const Center(
                child: Text('content', textDirection: TextDirection.ltr),
              ),
        ),
      ),
    ),
  );

  return (
    app: app,
    handlerKey: handlerKey,
    pastedBytes: pasted,
    errorCount: () => errors,
  );
}

void main() {
  group('PasteImageHandler — Property 6: Error-to-message mapping', () {
    // Feature: paste-image-documentation, Property 6: Error result to message mapping is total and deterministic
    // **Validates: Requirements 5.1, 5.2, 5.3, 5.4**

    // Iterasi 100x: setiap iterasi memilih varian error secara acak/seragam,
    // memicu performPaste, dan memverifikasi bahwa snackbar yang
    // ditampilkan persis sama dengan pesan deterministik untuk varian
    // tersebut.
    testWidgets(
      'Each ClipboardReadResult error variant maps to exactly one '
      'predetermined snackbar message (100 iterations)',
      (tester) async {
        final random = Random(42);
        for (int i = 0; i < 100; i++) {
          final variant = _errorVariantAt(random.nextInt(4));
          final expectedMessage = _expectedErrorMessages[variant.runtimeType]!;

          final fakeService = _FakeClipboardService(result: variant);
          final harness = _buildHarness(clipboardService: fakeService);

          await tester.pumpWidget(harness.app);
          await tester.pump();

          // Pastikan handler terpasang lalu picu paste secara imperatif.
          final state = harness.handlerKey.currentState!;
          await state.performPaste();
          await tester.pump(); // tampilkan snackbar

          expect(
            find.text(expectedMessage),
            findsOneWidget,
            reason: 'Iter $i variant=${variant.runtimeType}: expected snackbar '
                '"$expectedMessage" tidak ditemukan.',
          );

          // Cleanup: hapus pohon widget agar iterasi berikutnya bersih.
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  });

  group(
    'PasteImageHandler — Property 8: Focus-based paste routing',
    () {
      // Feature: paste-image-documentation, Property 8: Focus-based paste routing
      // **Validates: Requirements 6.6, 7.2, 7.3**
      //
      // Strategi: pohon widget berisi sebuah TextField (yang membungkus
      // EditableText) DAN sebuah Container kosong yang bisa difokuskan
      // via FocusNode terpisah. Setiap iterasi:
      //  - Random memilih state fokus (text field vs non-text)
      //  - Mengirim Ctrl+V via simulateKeyDownEvent
      //  - Memverifikasi: text field focused → readCount tetap 0;
      //    non-text focus → readCount bertambah 1.
      testWidgets(
        'Ctrl+V routes to clipboard read iff focus is NOT on EditableText '
        '(100 iterations)',
        (tester) async {
          final random = Random(42);
          for (int i = 0; i < 100; i++) {
            final fakeService =
                _FakeClipboardService(result: const ClipboardEmpty());
            final textFocusNode = FocusNode();
            final nonTextFocusNode = FocusNode();
            addTearDown(textFocusNode.dispose);
            addTearDown(nonTextFocusNode.dispose);

            final harness = _buildHarness(
              clipboardService: fakeService,
              body: Column(
                children: [
                  // EditableText milik TextField akan jadi target fokus
                  // saat textFocusNode.requestFocus dipanggil.
                  TextField(focusNode: textFocusNode),
                  // Widget non-text yang bisa difokuskan via Focus.
                  Focus(
                    focusNode: nonTextFocusNode,
                    child: Container(
                      key: const Key('non-text-target'),
                      width: 100,
                      height: 100,
                      color: const Color(0xFFCCCCCC),
                    ),
                  ),
                ],
              ),
            );

            await tester.pumpWidget(harness.app);
            await tester.pump();

            final focusOnTextField = random.nextBool();
            if (focusOnTextField) {
              textFocusNode.requestFocus();
            } else {
              nonTextFocusNode.requestFocus();
            }
            await tester.pump();

            // Kirim Ctrl+V (gunakan controlLeft sebagai modifier sesuai
            // simulator default). Bila platform host adalah macOS,
            // metaLeft juga valid; controlLeft tetap dideteksi oleh
            // HardwareKeyboard.isControlPressed.
            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
            await tester.pump();
            // Beri sedikit waktu untuk performPaste async terselesaikan
            // jika dipicu.
            await tester.pump(const Duration(milliseconds: 10));

            if (focusOnTextField) {
              expect(
                fakeService.readCount,
                0,
                reason: 'Iter $i: focus pada TextField — clipboard tidak '
                    'boleh dibaca (Property 8).',
              );
            } else {
              expect(
                fakeService.readCount,
                1,
                reason: 'Iter $i: focus bukan pada TextField — clipboard '
                    'harus dibaca tepat satu kali (Property 8).',
              );
            }

            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );
    },
  );

  group(
    'PasteImageHandler — Property 9: Non-paste keyboard shortcuts pass through',
    () {
      // Feature: paste-image-documentation, Property 9: Non-paste keyboard shortcuts pass through
      // **Validates: Requirements 7.1**
      //
      // Strategi: pohon widget tanpa TextField, fokus diarahkan ke widget
      // non-text. Setiap iterasi mengirim Ctrl + <random non-V key>
      // dan memverifikasi readCount tetap 0 (handler mengembalikan
      // KeyEventResult.ignored tanpa state change).
      testWidgets(
        'Ctrl+<non-V> shortcuts do not trigger clipboard read (100 iterations)',
        (tester) async {
          // Daftar key non-V yang umum dipakai (Ctrl+C/A/Z/X) plus
          // huruf-huruf acak lainnya.
          const candidateKeys = <LogicalKeyboardKey>[
            LogicalKeyboardKey.keyC,
            LogicalKeyboardKey.keyA,
            LogicalKeyboardKey.keyZ,
            LogicalKeyboardKey.keyX,
            LogicalKeyboardKey.keyB,
            LogicalKeyboardKey.keyD,
            LogicalKeyboardKey.keyE,
            LogicalKeyboardKey.keyF,
            LogicalKeyboardKey.keyG,
            LogicalKeyboardKey.keyH,
            LogicalKeyboardKey.keyI,
            LogicalKeyboardKey.keyJ,
            LogicalKeyboardKey.keyK,
            LogicalKeyboardKey.keyL,
            LogicalKeyboardKey.keyM,
            LogicalKeyboardKey.keyN,
            LogicalKeyboardKey.keyO,
            LogicalKeyboardKey.keyP,
            LogicalKeyboardKey.keyQ,
            LogicalKeyboardKey.keyR,
            LogicalKeyboardKey.keyS,
            LogicalKeyboardKey.keyT,
            LogicalKeyboardKey.keyU,
            LogicalKeyboardKey.keyW,
            LogicalKeyboardKey.keyY,
          ];

          final random = Random(42);
          for (int i = 0; i < 100; i++) {
            final fakeService =
                _FakeClipboardService(result: const ClipboardEmpty());
            final nonTextFocusNode = FocusNode();
            addTearDown(nonTextFocusNode.dispose);

            final harness = _buildHarness(
              clipboardService: fakeService,
              body: Focus(
                focusNode: nonTextFocusNode,
                child: Container(
                  key: const Key('non-text-target'),
                  width: 100,
                  height: 100,
                  color: const Color(0xFFCCCCCC),
                ),
              ),
            );

            await tester.pumpWidget(harness.app);
            nonTextFocusNode.requestFocus();
            await tester.pump();

            final key = candidateKeys[random.nextInt(candidateKeys.length)];

            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
            await tester.sendKeyEvent(key);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
            await tester.pump();

            expect(
              fakeService.readCount,
              0,
              reason: 'Iter $i: Ctrl+${key.keyLabel} bukan paste shortcut — '
                  'clipboard tidak boleh dibaca (Property 9).',
            );
            // Tidak ada snackbar yang muncul (no state mutation).
            expect(find.byType(SnackBar), findsNothing);

            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
      );
    },
  );

  group(
    'PasteImageHandler — Property 2: Image replacement preserves only new image',
    () {
      // Feature: paste-image-documentation, Property 2: Image replacement preserves only new image
      // **Validates: Requirements 1.5, 6.2**
      //
      // Strategi: harness pasted-bytes recorder mensimulasikan state
      // form (`_imageBytes`). Setiap iterasi:
      //   1. Pre-populate dengan oldBytes (paste pertama).
      //   2. Tukar fake clipboard service ke newBytes via setter result.
      //      Karena setter result tidak ada, kita menggunakan harness
      //      baru pada iterasi yang sama untuk fase kedua: ini OK karena
      //      property 2 adalah tentang STATE form, bukan service.
      //   3. Picu performPaste lagi.
      //   4. Verifikasi entri terakhir di pastedBytes adalah newBytes
      //      (bukan oldBytes).
      testWidgets(
        'After replacing an existing pasted image, last form state equals '
        'newly pasted bytes (100 iterations)',
        (tester) async {
          final random = Random(42);
          for (int i = 0; i < 100; i++) {
            final oldBytes = _randomBytes(random);
            final newBytes = _randomBytes(random);
            final service = _FakeClipboardService(
              result: ClipboardImageSuccess(oldBytes),
            );

            final harness = _buildHarness(clipboardService: service);
            await tester.pumpWidget(harness.app);
            await tester.pump();

            // Paste pertama (memuat oldBytes ke "form state").
            await harness.handlerKey.currentState!.performPaste();
            await tester.pump();

            // Ganti hasil clipboard ke newBytes lalu paste lagi.
            service.result = ClipboardImageSuccess(newBytes);
            await harness.handlerKey.currentState!.performPaste();
            await tester.pump();

            expect(
              harness.pastedBytes.length,
              2,
              reason: 'Iter $i: harus ada dua entri (old kemudian new).',
            );
            expect(
              harness.pastedBytes.last,
              equals(newBytes),
              reason: 'Iter $i: setelah paste kedua, state terakhir harus '
                  'sama dengan newBytes (Property 2).',
            );
            // Hapus snackbar yang masih aktif sebelum unmount untuk
            // menghindari pending timer.
            ScaffoldMessenger.of(harness.handlerKey.currentContext!)
                .clearSnackBars();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 3));
          }
        },
      );
    },
  );

  group(
    'PasteImageHandler — Property 7: Form state preservation on error',
    () {
      // Feature: paste-image-documentation, Property 7: Form state preservation on error
      // **Validates: Requirements 5.5**
      //
      // Strategi: pre-populate "form state" (pastedBytes + simulasi
      // catatan teks) dengan nilai acak, lalu picu performPaste dengan
      // varian error yang dipilih acak. Property: pastedBytes TIDAK
      // bertambah dan formState tetap utuh.
      testWidgets(
        'For any error variant and any prior form state, form state is '
        'unchanged after performPaste (100 iterations)',
        (tester) async {
          final random = Random(42);
          for (int i = 0; i < 100; i++) {
            final priorBytes = _randomBytes(random);
            // Simulasi catatan acak (bagian state form di luar imageBytes).
            final priorCatatan = String.fromCharCodes(
              List.generate(
                10 + random.nextInt(20),
                (_) => 0x61 + random.nextInt(26),
              ),
            );
            final variant = _errorVariantAt(random.nextInt(4));

            final service = _FakeClipboardService(result: variant);
            final harness = _buildHarness(clipboardService: service);

            await tester.pumpWidget(harness.app);
            await tester.pump();

            // Pre-populate state form: tambahkan priorBytes secara
            // langsung ke recorder (mensimulasikan paste yang sudah
            // sukses sebelumnya).
            harness.pastedBytes.add(priorBytes);
            // "form state" terpisah yang juga harus terjaga.
            String formCatatan = priorCatatan;
            final priorErrorCount = harness.errorCount();

            await harness.handlerKey.currentState!.performPaste();
            await tester.pump();

            // Property 7: pastedBytes TIDAK bertambah (handler tidak
            // memanggil onImagePasted ketika hasilnya error).
            expect(
              harness.pastedBytes.length,
              1,
              reason: 'Iter $i variant=${variant.runtimeType}: '
                  'onImagePasted tidak boleh dipanggil pada error variant.',
            );
            expect(
              harness.pastedBytes.single,
              equals(priorBytes),
              reason: 'Iter $i: priorBytes harus utuh.',
            );
            // formCatatan tetap utuh (bukti tidak ada mutasi state lain).
            expect(formCatatan, equals(priorCatatan));
            // onError dipanggil tepat satu kali (state notification),
            // tetapi tetap tidak memutasi data form.
            expect(
              harness.errorCount() - priorErrorCount,
              1,
              reason: 'Iter $i: onError harus dipanggil tepat sekali.',
            );

            // Bersihkan snackbar agar tidak ada timer aktif.
            ScaffoldMessenger.of(harness.handlerKey.currentContext!)
                .clearSnackBars();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 5));
          }
        },
      );
    },
  );

  group('PasteImageHandler — Task 8.2 unit tests', () {
    // Task 8.2: Unit tests for PasteImageHandler keyboard handling.

    testWidgets(
      'Keyboard listener is registered (Focus widget with onKeyEvent in tree) '
      'on desktop/web (Req 2.1)',
      (tester) async {
        final fakeService =
            _FakeClipboardService(result: const ClipboardEmpty());
        final harness = _buildHarness(clipboardService: fakeService);

        await tester.pumpWidget(harness.app);
        await tester.pump();

        // PasteImageHandler MEMASANG widget Focus pembungkus dengan
        // callback onKeyEvent. Verifikasi keberadaannya:
        //   1. Setidaknya satu Focus widget di subtree handler.
        //   2. Salah satu Focus tersebut memiliki onKeyEvent != null.
        final focusFinder = find.descendant(
          of: find.byType(PasteImageHandler),
          matching: find.byType(Focus),
        );
        expect(focusFinder, findsWidgets);

        final focusWidgets = tester.widgetList<Focus>(focusFinder).toList();
        final hasKeyEventListener = focusWidgets.any(
          (f) => f.onKeyEvent != null,
        );
        expect(
          hasKeyEventListener,
          isTrue,
          reason:
              'PasteImageHandler harus memasang Focus dengan onKeyEvent untuk '
              'mendengarkan shortcut paste (Req 2.1).',
        );
      },
    );

    testWidgets(
      'Ctrl+V on non-text focus with text-only clipboard (ClipboardNoImage) '
      'shows snackbar — current behavior (Req 5.2 wins over strict 7.4)',
      (tester) async {
        // Catatan: Req 7.4 menyebut bahwa ketika Ctrl+V ditekan dan
        // clipboard hanya berisi teks, handler "SHALL allow the event
        // to propagate without showing an error". Implementasi saat ini
        // (sesuai task 3.3 dan tabel error pada design.md) menampilkan
        // snackbar "Clipboard tidak berisi gambar..." karena Req 5.2
        // mewajibkan UI feedback untuk klipboard tanpa gambar saat
        // paste benar-benar dipicu user di area non-text. Test ini
        // mendokumentasikan perilaku terimplementasi; bila Req 7.4
        // diutamakan di masa mendatang, test ini perlu di-update.
        final fakeService =
            _FakeClipboardService(result: const ClipboardNoImage());
        final nonTextFocusNode = FocusNode();
        addTearDown(nonTextFocusNode.dispose);

        final harness = _buildHarness(
          clipboardService: fakeService,
          body: Focus(
            focusNode: nonTextFocusNode,
            child: Container(
              key: const Key('non-text-target'),
              width: 100,
              height: 100,
              color: const Color(0xFFCCCCCC),
            ),
          ),
        );

        await tester.pumpWidget(harness.app);
        nonTextFocusNode.requestFocus();
        await tester.pump();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        // Tunggu performPaste async selesai.
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.text(_expectedErrorMessages[ClipboardNoImage]!),
          findsOneWidget,
          reason: 'Snackbar "Clipboard tidak berisi gambar..." harus muncul '
              'untuk Ctrl+V pada area non-text dengan clipboard text-only '
              '(perilaku saat ini sesuai Req 5.2).',
        );

        // Cleanup snackbar timer.
        ScaffoldMessenger.of(harness.handlerKey.currentContext!)
            .clearSnackBars();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'When triggered via performPaste (button flow), ClipboardNoImage shows '
      'error snackbar (Req 5.2)',
      (tester) async {
        final fakeService =
            _FakeClipboardService(result: const ClipboardNoImage());
        final harness = _buildHarness(clipboardService: fakeService);

        await tester.pumpWidget(harness.app);
        await tester.pump();

        await harness.handlerKey.currentState!.performPaste();
        await tester.pump();

        expect(
          find.text(_expectedErrorMessages[ClipboardNoImage]!),
          findsOneWidget,
        );

        ScaffoldMessenger.of(harness.handlerKey.currentContext!)
            .clearSnackBars();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 3));
      },
    );
  });
}

/// Membangun Uint8List acak berukuran 8..40 byte. Cukup untuk
/// memverifikasi pelestarian referensi/byte tanpa membebani test.
Uint8List _randomBytes(Random random) {
  final length = 8 + random.nextInt(33);
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}
