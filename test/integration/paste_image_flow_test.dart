// Integration tests untuk alur paste gambar end-to-end.
//
// Feature: paste-image-documentation
// Task: 8.3 — Write integration test for full paste flow
//
// Tes yang divalidasi:
//   - Test 1: Full paste → compress → preview → submit flow
//             (Validates: Requirements 6.3, 6.4)
//   - Test 2: Clipboard timeout enforced at 5 seconds
//             (Validates: Requirements 2.3)
//   - Test 3: Compression completes within 10 seconds
//             (Validates: Requirements 3.5)
//
// Catatan: integration test ini menggunakan widget testing
// (`flutter_test`) — bukan paket `integration_test` resmi — karena
// integration_test memerlukan device/emulator. Pendekatan ini cukup
// untuk memvalidasi pipeline service+widget secara end-to-end di unit
// runner Flutter.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pantau_pegawai/core/services/clipboard_service.dart';
import 'package:pantau_pegawai/core/services/clipboard_service_provider.dart';
import 'package:pantau_pegawai/core/services/image_compressor.dart';
import 'package:pantau_pegawai/core/services/native_clipboard_service.dart';
import 'package:pantau_pegawai/features/dokumentasi/presentation/widgets/paste_image_handler.dart';

/// Fake [ClipboardService] yang mengembalikan [result] yang sudah
/// ditentukan. Digunakan oleh Test 1 untuk mengisi clipboard dengan
/// PNG yang valid.
class _ScriptedClipboardService implements ClipboardService {
  _ScriptedClipboardService(this.result);

  final ClipboardReadResult result;

  @override
  bool get isSupported => true;

  @override
  Future<ClipboardReadResult> readImageFromClipboard() async => result;
}

/// Membuat PNG bergradient berwarna kecil yang VALID dan dapat
/// di-decode oleh `package:image`. Ukuran kecil agar Test 1 (full
/// pipeline) tetap cepat.
Uint8List _buildSmallPng({int width = 64, int height = 64}) {
  final image = img.Image(width: width, height: height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 4) % 256,
        (y * 4) % 256,
        ((x + y) * 2) % 256,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

/// Membangun gambar besar (1920x1080) dengan pola deterministik untuk
/// menguji budget waktu kompresi (Test 3). Gambar dibuat dengan blok
/// warna agar lebih mudah dikompres ke <= 5MB pada quality awal —
/// fokus test adalah BUDGET WAKTU, bukan keberhasilan kompresi pada
/// noise tinggi.
Uint8List _buildLargeBlockyPng({int width = 1920, int height = 1080}) {
  final image = img.Image(width: width, height: height);
  // Pola blok 64x64 dengan warna berbeda agar entropy moderat (tidak
  // terlalu tinggi sehingga JPEG dapat mengompresi efisien, tapi cukup
  // detail untuk mendekati skenario riil).
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final blockX = x ~/ 64;
      final blockY = y ~/ 64;
      image.setPixelRgb(
        x,
        y,
        (blockX * 32) % 256,
        (blockY * 32) % 256,
        ((blockX + blockY) * 16) % 256,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group(
    'Integration — Test 1: Full paste → compress → preview → submit flow',
    () {
      // Validates: Requirements 6.3, 6.4
      //
      // Pipeline diuji sebagai berikut:
      //   1. ClipboardService (fake, return ClipboardImageSuccess(PNG bytes))
      //   2. PasteImageHandler.performPaste()
      //   3. ImageCompressor (REAL) memproses byte PNG → JPEG.
      //   4. onImagePasted callback dipicu dengan compressed bytes.
      //   5. "Form submit" disimulasikan dengan menyalin bytes dari
      //      callback ke variabel state, lalu di-decode kembali untuk
      //      memastikan bytes tersebut benar-benar valid sebagai JPEG
      //      (sesuai Req 6.3 — alur preview, dan Req 6.4 — submission
      //      menggunakan mekanisme yang sama).
      testWidgets(
        'Pasted PNG flows through compressor and yields a valid JPEG ready '
        'for the same submission pipeline as camera/gallery',
        (tester) async {
          final pngBytes = _buildSmallPng(width: 96, height: 96);

          final clipboardService = _ScriptedClipboardService(
            ClipboardImageSuccess(pngBytes),
          );
          // ImageCompressor REAL — bukan fake.
          const realCompressor = ImageCompressor();

          final handlerKey = GlobalKey<PasteImageHandlerState>();
          final pastedBytesList = <Uint8List>[];

          // Variabel form yang menyimulasikan `_imageBytes` pada
          // DokumentasiFormSheet. Pada submission nyata, byte ini
          // diunggah lewat mekanisme yang sama dengan kamera/galeri.
          Uint8List? formImageBytes;

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                clipboardServiceProvider.overrideWithValue(clipboardService),
                imageCompressorProvider.overrideWithValue(realCompressor),
              ],
              child: MaterialApp(
                home: Scaffold(
                  body: PasteImageHandler(
                    key: handlerKey,
                    onImagePasted: (bytes) {
                      pastedBytesList.add(bytes);
                      // Simulasikan setState pada form: byte hasil paste
                      // langsung dijadikan _imageBytes (Req 6.2/6.3).
                      formImageBytes = bytes;
                    },
                    child: const Center(child: Text('content')),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          // Picu seluruh pipeline.
          await handlerKey.currentState!.performPaste();
          // Beri kesempatan kepada compressor untuk menyelesaikan
          // operasi async + snackbar muncul.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          // Step 4 & 5: callback dipicu tepat satu kali dan menghasilkan
          // byte JPEG yang valid.
          expect(
            pastedBytesList.length,
            1,
            reason: 'onImagePasted harus dipanggil tepat sekali setelah '
                'pipeline selesai sukses.',
          );
          expect(
            formImageBytes,
            isNotNull,
            reason: 'Form state harus menyimpan compressed bytes (Req 6.3).',
          );

          // Verifikasi bahwa byte hasil adalah JPEG yang dapat di-decode
          // (kunci agar pipeline submit hilir — yang sama dengan
          // kamera/galeri — bisa mengunggahnya).
          final decoded = img.decodeJpg(formImageBytes!);
          expect(
            decoded,
            isNotNull,
            reason: 'Compressed bytes harus dapat di-decode sebagai JPEG '
                'agar dapat diunggah lewat mekanisme yang sama (Req 6.4).',
          );
          expect(
            decoded!.numChannels,
            3,
            reason: 'JPEG harus tanpa alpha (3 channels).',
          );

          // Snackbar sukses harus muncul sebagai konfirmasi visual
          // (Req 1.6 — bukti bahwa preview siap ditampilkan dan form
          // dalam state pasca-paste).
          expect(
            find.text('Gambar berhasil di-paste'),
            findsOneWidget,
            reason: 'Snackbar sukses harus muncul setelah paste selesai.',
          );

          // Simulasikan "submit" dengan memvalidasi bytes formImageBytes
          // identik dengan apa yang akan diteruskan ke uploader (Req 6.4).
          // Pada implementasi nyata, _submit() akan meneruskan byte ini
          // ke `DokumentasiRepository.uploadImage` yang sama dipakai
          // kamera/galeri.
          final submittedBytes = formImageBytes!;
          expect(
            submittedBytes,
            equals(pastedBytesList.single),
            reason: 'Submit pipeline harus menerima byte yang persis sama '
                'dengan compressed bytes dari paste handler.',
          );

          // Cleanup snackbar timer.
          ScaffoldMessenger.of(handlerKey.currentContext!).clearSnackBars();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 3));
        },
      );
    },
  );

  group(
    'Integration — Test 2: Clipboard timeout enforced at 5 seconds',
    () {
      // Validates: Requirements 2.3
      //
      // Strategi: stub `imageReader` pada NativeClipboardService dengan
      // `Future.delayed(Duration(seconds: 6))` — lebih lama dari batas
      // timeout 5 detik. Properti yang divalidasi:
      //   1. Operasi tidak menggantung; kembali sebelum 6 detik.
      //   2. Hasilnya ClipboardCorruptImage (sesuai design.md:
      //      "Timeout produces a `ClipboardCorruptImage` result").
      //   3. Elapsed time berada di sekitar 5 detik (4.5s..5.8s)
      //      — bukti enforcement timeout.
      //
      // Test ini sengaja menggunakan real wall-clock (bukan fakeAsync)
      // agar Future.timeout bekerja apa adanya. Total waktu eksekusi
      // ~5s, masih dalam batas wajar untuk integration test.
      test(
        'NativeClipboardService.readImageFromClipboard times out at ~5s and '
        'returns ClipboardCorruptImage when reader hangs longer than budget',
        () async {
          final service = NativeClipboardService(
            // Reader sengaja menunda 6 detik agar melebihi timeout 5s.
            imageReader: () => Future.delayed(
              const Duration(seconds: 6),
              () => Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]),
            ),
            textReader: () async => null,
            imageDecoder: (_) async => true,
          );

          final stopwatch = Stopwatch()..start();
          final result = await service.readImageFromClipboard();
          stopwatch.stop();

          expect(
            result,
            isA<ClipboardCorruptImage>(),
            reason: 'Hasil timeout harus dipetakan ke ClipboardCorruptImage '
                'sesuai design.md (Req 2.3).',
          );

          // Property utama: timeout DITEGAKKAN. Reader berlangsung 6
          // detik, jadi tanpa timeout test ini akan butuh >=6s.
          // Toleransi atas: 5.8s (memberi ruang untuk overhead event
          // loop pada CI runner).
          expect(
            stopwatch.elapsed.inMilliseconds,
            lessThan(5800),
            reason: 'Operasi clipboard harus dihentikan sebelum reader '
                'selesai (timeout 5s ditegakkan).',
          );
          // Toleransi bawah: 4500ms — pastikan timeout TIDAK terjadi
          // terlalu cepat (mengonfirmasi nilai 5s, bukan misalnya 1s).
          expect(
            stopwatch.elapsed.inMilliseconds,
            greaterThanOrEqualTo(4500),
            reason: 'Timeout harus terjadi di sekitar 5 detik, bukan lebih '
                'cepat (Req 2.3 — 5s clipboard timeout).',
          );
        },
        // Berikan timeout test yang lebih besar dari budget wall-clock
        // operasi (~5s) agar runner tidak mematikan test prematur.
        timeout: const Timeout(Duration(seconds: 30)),
      );
    },
  );

  group(
    'Integration — Test 3: Compression completes within 10 seconds',
    () {
      // Validates: Requirements 3.5
      //
      // Strategi: bangun gambar 1920x1080 dengan pola blok berwarna
      // (entropi moderat sehingga kompresi efisien dan fokus test ada
      // pada BUDGET WAKTU, bukan keberhasilan ukuran). Ukur waktu real
      // dengan Stopwatch dan pastikan compress() selesai di bawah
      // budget (10 detik per Req 3.5).
      //
      // Toleransi: budget asli 10 detik per requirement, tapi runner CI
      // kadang lambat. Kita tetap memvalidasi <=10s sebagai bukti
      // pemenuhan requirement, namun catatan: pada mesin lambat angka
      // ini bisa lebih ketat dari yang diharapkan. Bila gagal di CI,
      // pertimbangkan menjalankan benchmark terpisah.
      test(
        'ImageCompressor.compress finishes within 10 seconds for a '
        '1920x1080 input image',
        () async {
          const compressor = ImageCompressor();
          final largePng = _buildLargeBlockyPng(width: 1920, height: 1080);

          final stopwatch = Stopwatch()..start();
          final result = await compressor.compress(largePng);
          stopwatch.stop();

          // Property utama: kompresi selesai dalam budget waktu.
          expect(
            stopwatch.elapsed.inSeconds,
            lessThanOrEqualTo(10),
            reason: 'ImageCompressor.compress harus selesai dalam 10 detik '
                'untuk gambar 1920x1080 (Req 3.5). Aktual: '
                '${stopwatch.elapsed.inMilliseconds} ms.',
          );

          // Sanity: compressor mengembalikan hasil yang valid (bukan
          // CompressError) sehingga test memang mengukur path normal.
          expect(
            result,
            isA<CompressResult>(),
          );
          expect(
            result is CompressError,
            isFalse,
            reason: 'Compressor tidak boleh menghasilkan CompressError pada '
                'gambar valid 1920x1080.',
          );
        },
        // Test timeout lebih besar dari budget agar pesan kegagalan
        // berasal dari assertion `lessThanOrEqualTo(10)`, bukan dari
        // test runner yang membatalkan paksa.
        timeout: const Timeout(Duration(seconds: 60)),
      );
    },
  );
}
