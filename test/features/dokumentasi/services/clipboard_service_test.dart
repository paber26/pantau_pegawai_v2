// Property-based tests untuk lapisan ClipboardService.
//
// Feature: paste-image-documentation
// Properties tercakup:
//   - Property 1: Valid image format acceptance (Req 1.2, 1.4)
//   - Property 10: Image priority in mixed clipboard (Req 7.5)
//
// Iterasi minimum 100 sesuai design.md. Test menggunakan helper
// `runProperty` / `runPropertyAsync` dari
// `test/test_helpers/property_runner.dart` untuk menjalankan banyak
// iterasi secara deterministik.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pantau_pegawai/core/services/clipboard_service.dart';
import 'package:pantau_pegawai/core/services/native_clipboard_service.dart';

import '../../../test_helpers/property_runner.dart';

/// Header byte yang valid untuk setiap format yang didukung. Generator
/// hanya perlu membungkus header ini dengan payload acak — header
/// memastikan byte sequence dianggap sebagai gambar oleh deteksi
/// format hilir.
const List<int> _pngHeader = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
];

const List<int> _jpegHeader = [0xFF, 0xD8, 0xFF, 0xE0];

const List<int> _webpHeaderRiff = [0x52, 0x49, 0x46, 0x46]; // "RIFF"
const List<int> _webpHeaderTag = [0x57, 0x45, 0x42, 0x50]; // "WEBP"

/// Membangun byte sequence dengan header gambar valid + payload acak.
///
/// Tidak harus benar-benar bisa di-decode oleh `dart:ui` — pada Property
/// 1 kita memverifikasi properti pelestarian byte oleh
/// [ClipboardImageSuccess], bukan validasi format.
Uint8List _generateBytesWithValidHeader(Random random, int iteration) {
  // Putar antara 3 format secara seragam.
  final formatChoice = iteration % 3;
  final List<int> header;
  switch (formatChoice) {
    case 0:
      header = _pngHeader;
      break;
    case 1:
      header = _jpegHeader;
      break;
    default:
      // WEBP header: "RIFF" <4 byte size> "WEBP"
      header = [..._webpHeaderRiff, 0x00, 0x00, 0x00, 0x00, ..._webpHeaderTag];
      break;
  }

  final payloadLength = 16 + random.nextInt(512);
  final bytes = Uint8List(header.length + payloadLength);
  bytes.setRange(0, header.length, header);
  for (int i = header.length; i < bytes.length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// Membangun gambar PNG kecil yang benar-benar valid (decodable) dengan
/// dimensi acak kecil agar fast. Dipakai di Property 10 untuk menjamin
/// validasi decode pada [NativeClipboardService] sukses.
Uint8List _generateDecodablePng(Random random) {
  final width = 8 + random.nextInt(24);
  final height = 8 + random.nextInt(24);
  final image = img.Image(width: width, height: height);
  // Isi dengan warna acak agar setiap iterasi menghasilkan byte berbeda.
  final r = random.nextInt(256);
  final g = random.nextInt(256);
  final b = random.nextInt(256);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('ClipboardService — Property 1: Valid image format acceptance', () {
    // Feature: paste-image-documentation, Property 1: Valid image format acceptance
    // **Validates: Requirements 1.2, 1.4**
    runProperty(
      'ClipboardImageSuccess preserves image bytes verbatim for PNG/JPEG/WEBP payloads',
      (random, i) {
        final bytes = _generateBytesWithValidHeader(random, i);

        final result = ClipboardImageSuccess(bytes);

        // Pelestarian byte: referensi sama (tidak ada copy/transformasi).
        expect(
          identical(result.imageBytes, bytes),
          isTrue,
          reason: 'ClipboardImageSuccess seharusnya menyimpan referensi byte '
              'persis seperti input clipboard tanpa transformasi.',
        );
        expect(result.imageBytes.length, bytes.length);
        // Pelestarian isi byte (defensif: bila implementasi diubah ke
        // copy, isi tetap harus identik).
        expect(result.imageBytes, equals(bytes));
      },
      iterations: 100,
    );

    runPropertyAsync(
      'NativeClipboardService.readImageFromClipboard returns input bytes verbatim '
      'for valid headers when decoder accepts',
      (random, i) async {
        final source = _generateBytesWithValidHeader(random, i);

        // Stub reader: kembalikan byte yang sama persis seperti yang
        // "ada" di clipboard, dan validator decode selalu sukses
        // (untuk fokus pada properti pelestarian byte).
        final service = NativeClipboardService(
          imageReader: () async => source,
          textReader: () async => null,
          imageDecoder: (_) async => true,
        );

        final result = await service.readImageFromClipboard();
        expect(result, isA<ClipboardImageSuccess>());
        final bytes = (result as ClipboardImageSuccess).imageBytes;
        expect(bytes, equals(source));
      },
      iterations: 100,
    );
  });

  group('ClipboardService — Property 10: Image priority in mixed clipboard',
      () {
    // Feature: paste-image-documentation, Property 10: Image priority in mixed clipboard content
    // **Validates: Requirements 7.5**
    runPropertyAsync(
      'When clipboard has both text and image, image is extracted '
      '(NativeClipboardService returns ClipboardImageSuccess with image bytes)',
      (random, i) async {
        final imageBytes = _generateDecodablePng(random);
        // Random text payload (not validated, just must be non-empty).
        final textLen = 1 + random.nextInt(64);
        final text = String.fromCharCodes(
          List.generate(textLen, (_) => 0x41 + random.nextInt(26)),
        );

        final service = NativeClipboardService(
          imageReader: () async => imageBytes,
          textReader: () async => text,
          // Validator bisa "real" karena PNG kita memang decodable, tapi
          // kita stub agar tidak bergantung pada engine binding di test
          // unit.
          imageDecoder: (_) async => true,
        );

        final result = await service.readImageFromClipboard();
        expect(result, isA<ClipboardImageSuccess>());
        final bytes = (result as ClipboardImageSuccess).imageBytes;
        expect(bytes, equals(imageBytes));
      },
      iterations: 100,
    );
  });
}
