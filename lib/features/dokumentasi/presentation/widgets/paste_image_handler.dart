import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/clipboard_service.dart';
import '../../../../core/services/clipboard_service_provider.dart';
import '../../../../core/services/image_compressor.dart';

/// Widget yang membungkus [child] untuk menangani shortcut paste gambar
/// (Ctrl+V / Cmd+V) pada platform desktop/web, dan menyediakan metode
/// publik [PasteImageHandlerState.performPaste] yang bisa dipanggil dari
/// parent (mis. tombol "Paste dari Clipboard" pada bottom sheet) lewat
/// `GlobalKey<PasteImageHandlerState>`.
///
/// Mengakses [ClipboardService] dan [ImageCompressor] melalui Riverpod ref,
/// dan memanggil [onImagePasted] dengan byte gambar yang sudah dikompresi
/// ketika operasi paste berhasil.
///
/// Logika deteksi shortcut:
/// - Hanya `KeyDownEvent` Ctrl+V / Cmd+V (logical key `keyV`) yang
///   dianggap sebagai paste shortcut.
/// - Jika fokus aktif berada pada [EditableText] (komponen internal
///   TextField/TextFormField), event dilewatkan agar paste teks bawaan
///   tetap berjalan normal.
/// - Jika fokus tidak pada text field, [PasteImageHandlerState.performPaste]
///   dipicu dan event ditandai `KeyEventResult.handled` agar tidak
///   dipropagasi.
/// - Shortcut lain (Ctrl+C, Ctrl+A, Ctrl+Z, Ctrl+X, dll.) selalu
///   mengembalikan `KeyEventResult.ignored` tanpa mengubah state.
///
/// _Validates: Requirements 1.1, 1.6, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7,_
///             _6.6, 7.1, 7.2, 7.3, 7.4, 7.5_
class PasteImageHandler extends ConsumerStatefulWidget {
  /// Widget anak yang akan dibungkus dengan handler paste.
  final Widget child;

  /// Callback yang dipanggil dengan byte gambar yang sudah dikompresi
  /// ketika paste berhasil.
  final ValueChanged<Uint8List> onImagePasted;

  /// Callback opsional yang dipanggil ketika operasi paste gagal.
  ///
  /// Penanganan UI error (mis. menampilkan snackbar) tetap dilakukan
  /// di dalam handler; callback ini berguna bagi parent widget yang
  /// ingin bereaksi terhadap kegagalan (misal logging atau analytics).
  final VoidCallback? onError;

  const PasteImageHandler({
    super.key,
    required this.child,
    required this.onImagePasted,
    this.onError,
  });

  @override
  PasteImageHandlerState createState() => PasteImageHandlerState();
}

/// State publik untuk [PasteImageHandler].
///
/// Sengaja dibuat publik agar parent widget bisa memanggil
/// [performPaste] lewat `GlobalKey<PasteImageHandlerState>` — misalnya
/// ketika user mengetuk tombol "Paste dari Clipboard" dari bottom sheet
/// image picker.
class PasteImageHandlerState extends ConsumerState<PasteImageHandler> {
  /// FocusNode internal yang dipakai oleh widget [Focus] pembungkus.
  ///
  /// Tidak meminta autofocus agar tidak mengganggu fokus default form
  /// (mis. TextField yang baru saja di-tap). Handler tetap menerima
  /// event keyboard via fokus parent yang bubble naik.
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'PasteImageHandlerFocus',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Mengecek apakah fokus utama saat ini berada pada widget
  /// [EditableText] (komponen internal yang dipakai TextField dan
  /// TextFormField untuk menerima input teks).
  ///
  /// Pemeriksaan dilakukan dua tahap untuk menjaga kebenaran ketika
  /// `EditableText` dibungkus oleh widget kustom:
  /// 1. Cek langsung apakah `primaryFocus.context.widget` adalah
  ///    [EditableText].
  /// 2. Bila bukan, telusuri leluhur konteks fokus untuk menemukan
  ///    [EditableText] terdekat menggunakan
  ///    [BuildContext.findAncestorWidgetOfExactType].
  ///
  /// Mengembalikan `false` bila tidak ada fokus aktif atau fokus
  /// tidak terhubung ke widget [EditableText] manapun.
  bool _isTextFieldFocused() {
    final FocusNode? primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) {
      return false;
    }

    final BuildContext? focusContext = primaryFocus.context;
    if (focusContext == null) {
      return false;
    }

    // Tahap 1: pengecekan langsung pada widget yang memiliki FocusNode.
    if (focusContext.widget is EditableText) {
      return true;
    }

    // Tahap 2: telusuri leluhur untuk menemukan EditableText terdekat.
    final EditableText? ancestor =
        focusContext.findAncestorWidgetOfExactType<EditableText>();
    return ancestor != null;
  }

  /// Handler event keyboard untuk widget [Focus].
  ///
  /// Logika:
  /// - Mengabaikan `KeyUpEvent` dan `KeyRepeatEvent`; hanya `KeyDownEvent`
  ///   yang dievaluasi agar paste tidak terpicu berkali-kali.
  /// - Bukan paste shortcut → `KeyEventResult.ignored` (event diteruskan).
  ///   Ini termasuk Ctrl+C, Ctrl+A, Ctrl+Z, Ctrl+X, dan kombinasi lain.
  /// - Paste shortcut tetapi fokus pada [EditableText] →
  ///   `KeyEventResult.ignored` agar TextField bisa melakukan paste teks.
  /// - Paste shortcut dan fokus bukan pada text field → memicu
  ///   [performPaste] (asynchronous, fire-and-forget) lalu mengembalikan
  ///   `KeyEventResult.handled` supaya event tidak dipropagasi lebih jauh.
  ///
  /// _Validates: Requirements 6.6, 7.1, 7.2, 7.3, 7.4, 7.5_
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final bool modifierPressed = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final bool isPasteShortcut =
        modifierPressed && event.logicalKey == LogicalKeyboardKey.keyV;

    if (!isPasteShortcut) {
      return KeyEventResult.ignored;
    }

    if (_isTextFieldFocused()) {
      return KeyEventResult.ignored;
    }

    // Fire-and-forget: alur penuh dijalankan secara asynchronous.
    unawaited(performPaste());
    return KeyEventResult.handled;
  }

  /// Mengeksekusi alur paste: baca clipboard → kompres → panggil callback.
  ///
  /// Dapat dipanggil dari luar (mis. ketika user mengetuk tombol
  /// "Paste dari Clipboard") melalui `GlobalKey<PasteImageHandlerState>`.
  ///
  /// Alur:
  /// 1. Panggil [ClipboardService.readImageFromClipboard].
  /// 2. Pada [ClipboardImageSuccess], teruskan byte ke
  ///    [ImageCompressor.compress].
  /// 3. Pada [CompressSuccess], panggil [PasteImageHandler.onImagePasted]
  ///    dengan byte hasil kompresi dan tampilkan snackbar sukses
  ///    "Gambar berhasil di-paste" selama 2 detik.
  /// 4. Pada varian error apapun, tampilkan snackbar dengan pesan dan
  ///    durasi sesuai tabel pemetaan, lalu panggil
  ///    [PasteImageHandler.onError].
  /// 5. Snackbar lama selalu di-dismiss dengan
  ///    `ScaffoldMessenger.hideCurrentSnackBar()` sebelum menampilkan
  ///    yang baru.
  ///
  /// _Validates: Requirements 1.1, 1.6, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_
  Future<void> performPaste() async {
    // Akses service melalui ref.read agar tidak memicu rebuild ketika
    // provider berubah (operasi imperatif).
    final ClipboardService clipboardService =
        ref.read(clipboardServiceProvider);
    final ImageCompressor imageCompressor = ref.read(imageCompressorProvider);

    final ClipboardReadResult readResult =
        await clipboardService.readImageFromClipboard();

    if (!mounted) return;

    switch (readResult) {
      case ClipboardImageSuccess(:final imageBytes):
        final CompressResult compressResult =
            await imageCompressor.compress(imageBytes);
        if (!mounted) return;
        _handleCompressResult(compressResult);
      case ClipboardEmpty():
        _showErrorSnackBar(
          'Clipboard kosong. Salin gambar terlebih dahulu.',
          const Duration(seconds: 3),
        );
      case ClipboardNoImage():
        _showErrorSnackBar(
          'Clipboard tidak berisi gambar. Salin screenshot terlebih dahulu.',
          const Duration(seconds: 3),
        );
      case ClipboardCorruptImage():
        _showErrorSnackBar(
          'Gagal membaca gambar dari clipboard. Coba salin ulang.',
          const Duration(seconds: 3),
        );
      case ClipboardPermissionDenied():
        _showErrorSnackBar(
          'Izin akses clipboard ditolak. Periksa pengaturan izin aplikasi.',
          const Duration(seconds: 4),
        );
      case ClipboardUnsupported():
        // UI seharusnya sudah disembunyikan ketika platform tidak
        // mendukung clipboard. Bila handler tetap dipanggil, jangan
        // tampilkan snackbar (graceful degradation), tetapi tetap
        // beri tahu parent via onError.
        widget.onError?.call();
    }
  }

  /// Menangani [CompressResult] hasil kompresi gambar.
  ///
  /// Pada sukses, byte hasil diteruskan ke [PasteImageHandler.onImagePasted]
  /// dan snackbar sukses ditampilkan. Pada kegagalan, snackbar error
  /// sesuai tabel pemetaan ditampilkan dan [PasteImageHandler.onError]
  /// dipanggil.
  void _handleCompressResult(CompressResult result) {
    switch (result) {
      case CompressSuccess(:final compressedBytes):
        widget.onImagePasted(compressedBytes);
        _showSuccessSnackBar(
          'Gambar berhasil di-paste',
          const Duration(seconds: 2),
        );
      case CompressTooLarge():
        _showErrorSnackBar(
          'Gambar terlalu besar. Coba gunakan gambar dengan resolusi lebih kecil.',
          const Duration(seconds: 3),
        );
      case CompressError():
        _showErrorSnackBar(
          'Gagal memproses gambar. Coba lagi.',
          const Duration(seconds: 3),
        );
    }
  }

  /// Menampilkan snackbar sukses.
  ///
  /// Selalu menutup snackbar sebelumnya melalui
  /// `ScaffoldMessenger.hideCurrentSnackBar()` sehingga pesan baru tidak
  /// menumpuk.
  void _showSuccessSnackBar(String message, Duration duration) {
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        duration: duration,
      ),
    );
  }

  /// Menampilkan snackbar error dan memanggil [PasteImageHandler.onError].
  ///
  /// Selalu menutup snackbar sebelumnya melalui
  /// `ScaffoldMessenger.hideCurrentSnackBar()` (Requirement 5.7).
  void _showErrorSnackBar(String message, Duration duration) {
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: duration,
      ),
    );
    widget.onError?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }
}
