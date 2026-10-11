import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
// Conditional import: di web dimuat kotak tempel berbasis elemen HTML; di
// platform non-web (yang punya `dart.library.io`) dimuat stub kosong.
import 'paste_target_box_web.dart'
    if (dart.library.io) 'paste_target_box_stub.dart';

/// Menampilkan [PastePhotoDialog] dan mengembalikan byte JPEG foto yang
/// ditempel, atau `null` bila dibatalkan.
Future<Uint8List?> showPastePhotoDialog(BuildContext context) {
  return showDialog<Uint8List>(
    context: context,
    builder: (_) => const PastePhotoDialog(),
  );
}

/// Dialog berisi kotak tempel untuk browser iPhone.
///
/// Tombol "Paste dari Clipboard" biasa memakai `navigator.clipboard.read()`,
/// yang di iPhone hanya bisa membaca screenshot (PNG). Lewat kotak ini,
/// pengguna menekan lama lalu memilih Tempel, sehingga foto kamera dari
/// aplikasi Foto juga bisa masuk.
class PastePhotoDialog extends StatefulWidget {
  const PastePhotoDialog({super.key});

  @override
  State<PastePhotoDialog> createState() => _PastePhotoDialogState();
}

class _PastePhotoDialogState extends State<PastePhotoDialog> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tempel Foto'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Salin foto atau screenshot, lalu tekan lama kotak di bawah '
              'dan pilih Tempel.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: PasteTargetBox(
                onImage: (bytes) => Navigator.of(context).pop(bytes),
                onError: (message) => setState(() => _error = message),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}
