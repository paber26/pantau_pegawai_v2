import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

import 'clipboard_service.dart';

/// Implementasi [ClipboardService] untuk platform native (mobile & desktop).
///
/// Menggunakan paket `pasteboard` untuk mengakses gambar dari clipboard
/// sistem pada Android, iOS, macOS, Windows, dan Linux. `pasteboard`
/// dibutuhkan karena `Clipboard.getData` bawaan Flutter hanya mendukung
/// teks.
///
/// Operasi pembacaan dibungkus dengan timeout 5 detik sesuai requirement
/// 2.3. Setiap kemungkinan hasil dipetakan ke varian
/// [ClipboardReadResult] yang sesuai sehingga lapisan UI bisa menampilkan
/// pesan yang tepat.
class NativeClipboardService implements ClipboardService {
  /// Batas waktu maksimum untuk membaca clipboard.
  static const Duration _readTimeout = Duration(seconds: 5);

  /// Konstruktor opsional untuk dependency injection (memudahkan testing).
  ///
  /// `imageReader` dan `textReader` defaultnya menggunakan
  /// [Pasteboard.image] dan [Pasteboard.text]; di test, fungsi-fungsi ini
  /// bisa diganti dengan stub.
  /// `imageDecoder` defaultnya memanggil [ui.instantiateImageCodec] untuk
  /// memvalidasi bahwa byte yang dibaca benar-benar gambar yang bisa
  /// di-decode.
  NativeClipboardService({
    Future<Uint8List?> Function()? imageReader,
    Future<String?> Function()? textReader,
    Future<bool> Function(Uint8List bytes)? imageDecoder,
  })  : _imageReader = imageReader ?? _defaultImageReader,
        _textReader = textReader ?? _defaultTextReader,
        _imageDecoder = imageDecoder ?? _defaultImageDecoder;

  final Future<Uint8List?> Function() _imageReader;
  final Future<String?> Function() _textReader;
  final Future<bool> Function(Uint8List bytes) _imageDecoder;

  static Future<Uint8List?> _defaultImageReader() => Pasteboard.image;

  static Future<String?> _defaultTextReader() => Pasteboard.text;

  /// Implementasi default untuk validasi decode gambar.
  ///
  /// Menggunakan [ui.instantiateImageCodec] untuk memastikan byte
  /// benar-benar PNG/JPEG/WEBP yang valid. Codec yang berhasil dibuat
  /// langsung di-dispose karena kita hanya butuh validasi.
  static Future<bool> _defaultImageDecoder(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isSupported => true;

  @override
  Future<ClipboardReadResult> readImageFromClipboard() async {
    try {
      final bytes = await _imageReader().timeout(_readTimeout);

      if (bytes != null && bytes.isNotEmpty) {
        final canDecode = await _imageDecoder(bytes).timeout(_readTimeout);
        if (canDecode) {
          return ClipboardImageSuccess(bytes);
        }
        return const ClipboardCorruptImage();
      }

      // Tidak ada gambar di clipboard. Periksa apakah ada konten teks
      // untuk membedakan clipboard kosong dari clipboard berisi non-gambar.
      try {
        final text = await _textReader().timeout(_readTimeout);
        if (text != null && text.isNotEmpty) {
          return const ClipboardNoImage();
        }
      } on TimeoutException {
        // Anggap kosong jika pembacaan teks pun gagal.
      } catch (_) {
        // Abaikan kegagalan pembacaan teks; perlakukan sebagai kosong.
      }

      return const ClipboardEmpty();
    } on TimeoutException {
      // Timeout diperlakukan sebagai gambar tidak terbaca (corrupt) sesuai
      // panduan error handling pada design.
      return const ClipboardCorruptImage();
    } on PlatformException catch (e) {
      // Beberapa platform menggunakan kode error berbeda untuk izin
      // ditolak. Cek pola umum sebelum jatuh ke fallback corrupt.
      final code = e.code.toLowerCase();
      final message = (e.message ?? '').toLowerCase();
      if (code.contains('permission') ||
          code.contains('denied') ||
          message.contains('permission') ||
          message.contains('denied')) {
        return const ClipboardPermissionDenied();
      }
      return const ClipboardCorruptImage();
    } catch (_) {
      return const ClipboardCorruptImage();
    }
  }
}
