import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Stub [PasteTargetBox] untuk platform non-web.
///
/// Kotak tempel hanya dipakai di browser iPhone (lihat
/// `paste_target_box_web.dart`). Di platform lain widget ini kosong.
class PasteTargetBox extends StatelessWidget {
  const PasteTargetBox({
    super.key,
    required this.onImage,
    required this.onError,
  });

  final ValueChanged<Uint8List> onImage;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
