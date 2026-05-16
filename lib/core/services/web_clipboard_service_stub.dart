// Stub implementation untuk [WebClipboardService] yang dimuat pada
// platform non-web melalui conditional import. File ini ada agar
// `web_clipboard_service.dart` (yang menggunakan `dart:js_interop`) tidak
// pernah ikut dikompilasi pada Android, iOS, macOS, Windows, atau Linux.
//
// Provider clipboard memilih [WebClipboardService] hanya bila `kIsWeb`
// bernilai true, sehingga konstruktor stub di bawah seharusnya tidak
// pernah dipanggil pada runtime non-web.

import 'clipboard_service.dart';

/// Stub class untuk `WebClipboardService` pada platform non-web.
///
/// Setiap pemanggilan akan melempar [UnsupportedError]. Pada praktiknya,
/// provider Riverpod tidak akan pernah membuat instance ini di luar web.
class WebClipboardService implements ClipboardService {
  WebClipboardService() {
    throw UnsupportedError(
      'WebClipboardService hanya tersedia pada platform web.',
    );
  }

  @override
  bool get isSupported => false;

  @override
  Future<ClipboardReadResult> readImageFromClipboard() async {
    return const ClipboardUnsupported();
  }
}
