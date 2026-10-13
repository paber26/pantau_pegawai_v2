import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/utils/image_url_utils.dart';
import 'drive_image.dart';

/// Menampilkan foto dokumentasi layar penuh.
///
/// Foto bisa di-zoom dengan dua jari. Penampil ditutup lewat tombol ✕,
/// ketuk area hitam di luar foto, geser foto ke bawah (saat tidak di-zoom),
/// atau tombol Esc.
Future<void> showPhotoViewer(BuildContext context, String imageUrl) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    useSafeArea: false,
    builder: (_) => PhotoViewer(child: _FullDriveImage(imageUrl: imageUrl)),
  );
}

/// Isi penampil foto layar penuh. [child] adalah fotonya; ukurannya
/// mengikuti foto (dipusatkan), sehingga ketukan di luar foto bisa dikenali.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.child});

  final Widget child;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  final TransformationController _transform = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransformChanged)
      ..dispose();
    super.dispose();
  }

  /// Geser ke bawah untuk menutup hanya saat tidak di-zoom; saat di-zoom,
  /// geser dipakai untuk menggeser foto.
  void _onTransformChanged() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Dismissible(
            key: const ValueKey('photo-viewer'),
            direction: _zoomed ? DismissDirection.none : DismissDirection.down,
            resizeDuration: null,
            dismissThresholds: const {DismissDirection.down: 0.2},
            onDismissed: (_) => _close(),
            child: InteractiveViewer(
              transformationController: _transform,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    // Ketukan yang tidak mengenai foto jatuh ke sini.
                    Positioned.fill(
                      child: GestureDetector(
                        key: const ValueKey('photo-viewer-backdrop'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _close,
                      ),
                    ),
                    Center(child: widget.child),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Tutup',
                  onPressed: _close,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close, size: 28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto Drive asli (lewat proxy gambar API) dengan ukuran mengikuti foto,
/// diperkecil agar muat di layar. Cache sama dengan `DriveImage`.
///
/// Selama foto asli dimuat, thumbnail dari daftar (biasanya sudah ada di
/// cache) langsung tampil diperbesar dengan indikator loading di atasnya.
class _FullDriveImage extends StatelessWidget {
  const _FullDriveImage({required this.imageUrl});

  final String imageUrl;

  static const Widget _broken =
      Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48);
  static const Widget _loading = CircularProgressIndicator(color: Colors.white);

  @override
  Widget build(BuildContext context) {
    final fileId = ImageUrlUtils.extractFileId(imageUrl);
    if (fileId == null) return _broken;
    final full = DriveImage.source(fileId, thumbnail: false);
    final thumb = DriveImage.source(fileId, thumbnail: true);
    return CachedNetworkImage(
      imageUrl: full.url,
      cacheKey: full.cacheKey,
      fit: BoxFit.contain,
      placeholder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          // Diperbesar sampai muat di layar, seperti foto aslinya nanti.
          // FittedBox hanya menerima ketukan di area foto, jadi ketuk area
          // hitam tetap menutup penampil.
          SizedBox.expand(
            child: FittedBox(
              child: CachedNetworkImage(
                imageUrl: thumb.url,
                cacheKey: thumb.cacheKey,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          _loading,
        ],
      ),
      errorWidget: (_, __, ___) => _broken,
    );
  }
}
