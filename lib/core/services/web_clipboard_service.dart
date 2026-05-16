// This implementation is web-only. It uses `dart:js_interop` to access the
// browser Clipboard API and therefore SHALL NOT be imported on non-web
// platforms. The Riverpod provider performs conditional importing so this
// file is only loaded when running on the web.
//
// _Validates: Requirements 2.4, 2.5, 2.3, 1.1_

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'clipboard_service.dart';

/// Implementasi [ClipboardService] untuk platform web.
///
/// Menggunakan API browser `navigator.clipboard.read()` (Async Clipboard
/// API) untuk membaca data gambar dari clipboard sistem. Mendukung format
/// PNG, JPEG, dan WEBP. Operasi dibatasi dengan timeout 5 detik sesuai
/// kebutuhan spesifikasi.
class WebClipboardService implements ClipboardService {
  /// Timeout untuk operasi pembacaan clipboard.
  static const Duration _readTimeout = Duration(seconds: 5);

  /// MIME type gambar yang didukung sesuai Requirement 1.4.
  static const Set<String> _supportedImageMimeTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
  };

  /// Apakah API clipboard yang dibutuhkan tersedia pada browser saat ini.
  ///
  /// Browser lama tanpa `navigator.clipboard.read` (mis. Safari versi
  /// awal) akan menyebabkan `isSupported` mengembalikan `false`, sehingga
  /// UI dapat menyembunyikan opsi paste sesuai Requirement 2.5.
  @override
  bool get isSupported {
    try {
      final clipboard = _navigatorClipboardOrNull();
      if (clipboard == null) return false;
      // `read` adalah method yang baru tersedia pada Async Clipboard API
      // modern. Kita memeriksa keberadaannya secara eksplisit.
      return clipboard.has('read'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ClipboardReadResult> readImageFromClipboard() async {
    try {
      return await _readImageFromClipboardImpl().timeout(
        _readTimeout,
        onTimeout: () => const ClipboardCorruptImage(),
      );
    } on _ClipboardPermissionException {
      return const ClipboardPermissionDenied();
    } catch (_) {
      // Kesalahan tak terduga (mis. browser melempar DOMException lain)
      // diperlakukan sebagai data clipboard yang tidak dapat dibaca.
      return const ClipboardCorruptImage();
    }
  }

  Future<ClipboardReadResult> _readImageFromClipboardImpl() async {
    final clipboard = _navigatorClipboardOrNull();
    if (clipboard == null) {
      return const ClipboardUnsupported();
    }
    if (!clipboard.has('read'.toJS).toDart) {
      return const ClipboardUnsupported();
    }

    final JSArray<_ClipboardItem> itemsArray;
    try {
      itemsArray = await clipboard.read().toDart;
    } on Object catch (e) {
      // Browser mengangkat error sebagai DOMException. NotAllowedError
      // (izin ditolak) dan SecurityError dipetakan ke
      // [ClipboardPermissionDenied] sesuai Requirement 5.4.
      if (_isPermissionError(e)) {
        throw const _ClipboardPermissionException();
      }
      rethrow;
    }

    final items = itemsArray.toDart;
    if (items.isEmpty) {
      return const ClipboardEmpty();
    }

    var sawAnyType = false;
    for (final item in items) {
      final types = item.types.toDart.map((t) => t.toDart).toList();
      if (types.isNotEmpty) sawAnyType = true;

      for (final type in types) {
        if (!_supportedImageMimeTypes.contains(type.toLowerCase())) continue;

        final JSAny? blobJs;
        try {
          blobJs = await item.getType(type.toJS).toDart;
        } on Object catch (e) {
          if (_isPermissionError(e)) {
            throw const _ClipboardPermissionException();
          }
          // Item mengaku punya tipe gambar tetapi gagal diakses; lanjut ke
          // tipe berikutnya bila ada.
          continue;
        }
        if (blobJs == null) continue;

        final blob = blobJs as _Blob;
        final Uint8List bytes;
        try {
          final buffer = await blob.arrayBuffer().toDart;
          bytes = buffer.toDart.asUint8List();
        } on Object {
          // Gagal membaca blob -> data dianggap corrupt.
          return const ClipboardCorruptImage();
        }
        if (bytes.isEmpty) {
          return const ClipboardCorruptImage();
        }

        final canDecode = await _canDecodeImage(bytes);
        if (!canDecode) {
          return const ClipboardCorruptImage();
        }

        return ClipboardImageSuccess(bytes);
      }
    }

    // Tidak ditemukan MIME type gambar yang didukung. Bedakan antara
    // clipboard yang benar-benar kosong (Requirement 5.1) dan clipboard
    // yang berisi konten lain seperti teks (Requirement 5.2).
    if (!sawAnyType) {
      return const ClipboardEmpty();
    }
    return const ClipboardNoImage();
  }

  /// Mengembalikan true bila [bytes] dapat di-decode sebagai gambar yang
  /// valid oleh codec gambar Flutter (mendukung PNG, JPEG, WEBP).
  Future<bool> _canDecodeImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Helper untuk mengakses `navigator.clipboard` dengan aman.
  /// Mengembalikan `null` bila tidak tersedia.
  _Clipboard? _navigatorClipboardOrNull() {
    final navigator = _globalNavigatorOrNull();
    if (navigator == null) return null;
    if (!navigator.has('clipboard'.toJS).toDart) return null;
    return navigator.clipboard;
  }

  _Navigator? _globalNavigatorOrNull() {
    try {
      final win = _globalWindow;
      if (win.isUndefinedOrNull) return null;
      if (!win.has('navigator'.toJS).toDart) return null;
      return win.navigator;
    } catch (_) {
      return null;
    }
  }

  /// Mendeteksi DOMException yang merepresentasikan penolakan izin.
  bool _isPermissionError(Object error) {
    final errorName = _readErrorName(error);
    if (errorName == null) return false;
    return errorName == 'NotAllowedError' || errorName == 'SecurityError';
  }

  String? _readErrorName(Object error) {
    try {
      if (error is JSObject) {
        if (!error.has('name'.toJS).toDart) return null;
        final nameJs = _objectGetProp(error, 'name'.toJS);
        if (nameJs == null) return null;
        if (nameJs.typeofEquals('string')) {
          return (nameJs as JSString).toDart;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

/// Sentinel exception internal untuk mengangkat error izin clipboard ke
/// pembungkus utama yang akan memetakannya ke [ClipboardPermissionDenied].
class _ClipboardPermissionException implements Exception {
  const _ClipboardPermissionException();
}

// ---------------------------------------------------------------------------
// Minimal `dart:js_interop` bindings.
//
// Kita mendefinisikan extension type lokal alih-alih bergantung pada
// `package:web` untuk menjaga dependensi proyek tetap minimal. Hanya
// permukaan API yang kita gunakan yang dibungkus.
// ---------------------------------------------------------------------------

@JS('window')
external _Window get _globalWindow;

extension type _Window._(JSObject _) implements JSObject {
  external _Navigator get navigator;
}

extension type _Navigator._(JSObject _) implements JSObject {
  external _Clipboard get clipboard;
}

extension type _Clipboard._(JSObject _) implements JSObject {
  external JSPromise<JSArray<_ClipboardItem>> read();
}

extension type _ClipboardItem._(JSObject _) implements JSObject {
  external JSArray<JSString> get types;
  external JSPromise<JSAny?> getType(JSString type);
}

extension type _Blob._(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

extension JSObjectHelpers on JSObject {
  /// Setara `Reflect.has(this, key)` — memeriksa keberadaan properti tanpa
  /// membaca nilainya, sehingga aman untuk fitur deteksi.
  JSBoolean has(JSString key) {
    return _objectHasProp(this, key);
  }
}

@JS('Reflect.has')
external JSBoolean _objectHasProp(JSObject target, JSString key);

@JS('Reflect.get')
external JSAny? _objectGetProp(JSObject target, JSString key);
