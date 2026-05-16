import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'clipboard_service.dart';
import 'image_compressor.dart';
import 'native_clipboard_service.dart';
// Conditional import: pada platform web file `web_clipboard_service.dart`
// yang asli (menggunakan `dart:js_interop`) dimuat. Pada platform non-web
// (yang memiliki `dart.library.io`), file stub dimuat sehingga binding
// `dart:js_interop` tidak ikut dikompilasi.
import 'web_clipboard_service.dart'
    if (dart.library.io) 'web_clipboard_service_stub.dart';

part 'clipboard_service_provider.g.dart';

/// Provider [ClipboardService] yang otomatis memilih implementasi sesuai
/// platform: [WebClipboardService] di web, [NativeClipboardService] pada
/// platform native (mobile & desktop).
///
/// _Validates: Requirements 2.3, 2.4_
@riverpod
ClipboardService clipboardService(Ref ref) {
  if (kIsWeb) {
    return WebClipboardService();
  }
  return NativeClipboardService();
}

/// Provider [ImageCompressor]. Diberikan sebagai provider Riverpod agar
/// mudah diganti (override) pada test.
///
/// _Validates: Requirements 2.3_
@riverpod
ImageCompressor imageCompressor(Ref ref) {
  return const ImageCompressor();
}
