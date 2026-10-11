// Implementasi web: memakai `dart:js_interop`, jadi TIDAK boleh diimpor di
// platform non-web. `paste_photo_dialog.dart` memakai conditional import
// sehingga platform lain memuat `paste_target_box_stub.dart`.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Kotak HTML `contenteditable` yang menerima foto lewat tekan lama → Tempel.
///
/// Dibuat untuk browser iPhone: `navigator.clipboard.read()` di WebKit hanya
/// membuka gambar PNG (screenshot), sedangkan event `paste` dari menu Tempel
/// iOS membawa foto kamera sebagai file (`image/jpeg`). Foto di-decode dan
/// diperkecil oleh browser (yang juga bisa membaca HEIC dan menerapkan
/// orientasi EXIF), lalu dikirim ke [onImage] sebagai JPEG.
class PasteTargetBox extends StatefulWidget {
  const PasteTargetBox({
    super.key,
    required this.onImage,
    required this.onError,
  });

  /// Dipanggil dengan byte JPEG ketika foto berhasil ditempel.
  final ValueChanged<Uint8List> onImage;

  /// Dipanggil dengan pesan untuk pengguna ketika tempel gagal.
  final ValueChanged<String> onError;

  @override
  State<PasteTargetBox> createState() => _PasteTargetBoxState();
}

class _PasteTargetBoxState extends State<PasteTargetBox> {
  static const String _placeholder = 'Tekan lama di sini, lalu pilih Tempel';

  /// Sisi terpanjang hasil konversi, sama dengan `ImageCompressor.maxDimension`.
  static const int _maxDimension = 1920;

  _HtmlElement? _box;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'div',
      onElementCreated: (Object element) => _setUp(element as _HtmlElement),
    );
  }

  void _setUp(_HtmlElement box) {
    _box = box;
    box
      ..setAttribute('contenteditable', 'true')
      // Tanpa keyboard virtual: kotak ini hanya untuk menempel.
      ..setAttribute('inputmode', 'none')
      ..setAttribute('role', 'textbox')
      ..setAttribute('aria-label', 'Kotak tempel foto')
      ..setAttribute('spellcheck', 'false')
      ..textContent = _placeholder;

    const Map<String, String> css = {
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'center',
      'box-sizing': 'border-box',
      'width': '100%',
      'height': '100%',
      'padding': '16px',
      'border': '2px dashed #1565C0',
      'border-radius': '12px',
      'background-color': 'rgba(21, 101, 192, 0.08)',
      'color': '#1565C0',
      'font-family':
          '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
      'font-size': '16px',
      'font-weight': '600',
      'text-align': 'center',
      'outline': 'none',
      'overflow': 'hidden',
      'caret-color': 'transparent',
      // Host Flutter mematikan seleksi teks; menu Tempel iOS butuh ini aktif.
      'user-select': 'text',
      '-webkit-user-select': 'text',
      '-webkit-touch-callout': 'default',
    };
    final _CssStyle style = box.style;
    css.forEach((name, value) => style.setProperty(name, value));

    box.addEventListener(
      'paste',
      ((_ClipboardEvent event) => _onPaste(event)).toJS,
    );
    // Cegah ketikan (keyboard fisik) atau hapus mengubah isi kotak.
    box.addEventListener(
      'beforeinput',
      ((_InputEvent event) {
        if (event.inputType != 'insertFromPaste') event.preventDefault();
      }).toJS,
    );
  }

  void _onPaste(_ClipboardEvent event) {
    // Kotak tidak pernah diisi oleh browser; hasil tempel diproses sendiri.
    event.preventDefault();
    if (_busy) return;

    final _File? file = _firstImageFile(event.clipboardData);
    if (file == null) {
      widget.onError(
        'Tidak ada foto yang ditempel. Salin foto dulu, lalu coba lagi.',
      );
      return;
    }
    unawaited(_convert(file));
  }

  _File? _firstImageFile(_DataTransfer? data) {
    if (data == null) return null;
    final _FileList files = data.files;
    for (var i = 0; i < files.length; i++) {
      final _File? file = files.item(i);
      if (file == null) continue;
      if (file.type.isEmpty || file.type.startsWith('image/')) return file;
    }
    return null;
  }

  Future<void> _convert(_File file) async {
    _busy = true;
    _box?.textContent = 'Memproses foto…';
    final String url = _createObjectUrl(file);
    try {
      final _ImageElement image = _ImageElement()..src = url;
      await image.decode().toDart;

      final int width = image.naturalWidth;
      final int height = image.naturalHeight;
      final int longest = width > height ? width : height;
      if (longest == 0) throw StateError('Ukuran gambar 0');
      final double scale =
          longest > _maxDimension ? _maxDimension / longest : 1;
      final int targetWidth = (width * scale).round();
      final int targetHeight = (height * scale).round();

      final _Canvas canvas = _document.createElement('canvas')
        ..width = targetWidth
        ..height = targetHeight;
      canvas.getContext('2d')
        ..fillStyle = '#ffffff'
        ..fillRect(0, 0, targetWidth, targetHeight)
        ..drawImage(image, 0, 0, targetWidth, targetHeight);

      final completer = Completer<_Blob?>();
      canvas.toBlob(
        ((_Blob? blob) => completer.complete(blob)).toJS,
        'image/jpeg',
        0.85,
      );
      final _Blob? blob = await completer.future;
      if (blob == null) throw StateError('Konversi JPEG gagal');
      final Uint8List bytes =
          (await blob.arrayBuffer().toDart).toDart.asUint8List();

      if (mounted) widget.onImage(bytes);
    } catch (_) {
      if (mounted) {
        widget.onError(
          'Foto tidak bisa dibaca. Coba foto lain atau pakai Pilih dari Galeri.',
        );
      }
    } finally {
      _revokeObjectUrl(url);
      _busy = false;
      if (mounted) _box?.textContent = _placeholder;
    }
  }
}

// Binding DOM minimal. Didefinisikan lokal (seperti
// `web_clipboard_service.dart`) agar tidak menambah dependensi `package:web`.

extension type _HtmlElement._(JSObject _) implements JSObject {
  external void setAttribute(String name, String value);
  external set textContent(String value);
  external _CssStyle get style;
  external void addEventListener(String type, JSFunction listener);
}

extension type _CssStyle._(JSObject _) implements JSObject {
  external void setProperty(String name, String value);
}

extension type _ClipboardEvent._(JSObject _) implements JSObject {
  external _DataTransfer? get clipboardData;
  external void preventDefault();
}

extension type _InputEvent._(JSObject _) implements JSObject {
  external String get inputType;
  external void preventDefault();
}

extension type _DataTransfer._(JSObject _) implements JSObject {
  external _FileList get files;
}

extension type _FileList._(JSObject _) implements JSObject {
  external int get length;
  external _File? item(int index);
}

extension type _File._(JSObject _) implements JSObject {
  external String get type;
}

extension type _Blob._(JSObject _) implements JSObject {
  external JSPromise<JSArrayBuffer> arrayBuffer();
}

@JS('Image')
extension type _ImageElement._(JSObject _) implements JSObject {
  external factory _ImageElement();
  external set src(String value);
  external JSPromise<JSAny?> decode();
  external int get naturalWidth;
  external int get naturalHeight;
}

@JS('document')
external _Document get _document;

extension type _Document._(JSObject _) implements JSObject {
  external _Canvas createElement(String tagName);
}

extension type _Canvas._(JSObject _) implements JSObject {
  external set width(int value);
  external set height(int value);
  external _Context2D getContext(String contextType);
  external void toBlob(JSFunction callback, String type, num quality);
}

extension type _Context2D._(JSObject _) implements JSObject {
  external set fillStyle(String value);
  external void fillRect(num x, num y, num width, num height);
  external void drawImage(
    _ImageElement image,
    num dx,
    num dy,
    num dWidth,
    num dHeight,
  );
}

@JS('URL.createObjectURL')
external String _createObjectUrl(_File file);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);
