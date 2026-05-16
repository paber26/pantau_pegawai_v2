import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Hasil dari operasi kompresi gambar oleh [ImageCompressor].
///
/// Sealed class dengan tiga varian:
///
/// - [CompressSuccess]: Gambar berhasil dikompres ke JPEG dalam batas
///   ukuran yang ditentukan.
/// - [CompressTooLarge]: Gambar tidak dapat dikompres di bawah
///   [ImageCompressor.maxSizeBytes] meskipun pada kualitas minimum
///   [ImageCompressor.minQuality].
/// - [CompressError]: Terjadi kesalahan tak terduga saat memproses
///   gambar (mis. byte tidak dapat di-decode).
sealed class CompressResult {
  const CompressResult();
}

/// Hasil sukses: [compressedBytes] berisi gambar JPEG terkompresi
/// yang sudah berada di bawah batas ukuran.
class CompressSuccess extends CompressResult {
  final Uint8List compressedBytes;

  const CompressSuccess(this.compressedBytes);
}

/// Gambar tidak dapat dikompres di bawah batas ukuran maksimum
/// meskipun pada kualitas minimum.
class CompressTooLarge extends CompressResult {
  const CompressTooLarge();
}

/// Kesalahan tak terduga saat memproses gambar.
///
/// [message] berisi deskripsi singkat kesalahan untuk keperluan
/// logging/diagnostik.
class CompressError extends CompressResult {
  final String message;

  const CompressError(this.message);
}

/// Kompresi dan resize gambar untuk diunggah.
///
/// Pipeline kompresi:
/// 1. Decode byte gambar masuk (mendukung PNG, JPEG, WEBP).
/// 2. Resize bila dimensi terbesar melebihi [maxDimension] dengan
///    mempertahankan rasio aspek.
/// 3. Ratakan alpha channel ke latar belakang putih (#FFFFFF) sehingga
///    output JPEG opaque.
/// 4. Encode JPEG mulai dari [startQuality]; jika hasil melebihi
///    [maxSizeBytes], turunkan kualitas sebesar [qualityStep] hingga
///    di bawah batas atau [minQuality] tercapai.
///
/// Jika tidak ada level kualitas yang menghasilkan output
/// <= [maxSizeBytes], dikembalikan [CompressTooLarge].
class ImageCompressor {
  /// Dimensi maksimum (lebar atau tinggi) sebelum gambar di-resize.
  static const int maxDimension = 1920;

  /// Ukuran maksimum hasil kompresi dalam byte (5 MB).
  static const int maxSizeBytes = 5 * 1024 * 1024;

  /// Kualitas awal JPEG saat encode (persen).
  static const int startQuality = 80;

  /// Kualitas minimum JPEG yang masih boleh dicoba (persen).
  static const int minQuality = 40;

  /// Penurunan kualitas pada setiap iterasi loop reduksi.
  static const int qualityStep = 10;

  const ImageCompressor();

  /// Mengompres [imageBytes] menjadi JPEG dalam batas ukuran.
  ///
  /// Mengembalikan:
  /// - [CompressSuccess] berisi byte JPEG bila berhasil dikompres.
  /// - [CompressTooLarge] bila tidak ada kualitas pada rentang
  ///   `[minQuality, startQuality]` (langkah [qualityStep]) yang
  ///   menghasilkan output <= [maxSizeBytes].
  /// - [CompressError] bila byte input tidak dapat di-decode atau
  ///   terjadi kesalahan tak terduga lainnya.
  Future<CompressResult> compress(Uint8List imageBytes) async {
    try {
      final img.Image? decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        return const CompressError('Tidak dapat men-decode byte gambar.');
      }

      final img.Image resized = _resizeIfNeeded(decoded);
      final img.Image flattened = _flattenAlpha(resized);

      for (int quality = startQuality;
          quality >= minQuality;
          quality -= qualityStep) {
        final List<int> encoded = img.encodeJpg(flattened, quality: quality);
        if (encoded.length <= maxSizeBytes) {
          return CompressSuccess(Uint8List.fromList(encoded));
        }
      }

      return const CompressTooLarge();
    } catch (e) {
      return CompressError('Gagal memproses gambar: $e');
    }
  }

  /// Mengembalikan salinan [image] yang sudah di-resize bila salah satu
  /// sisinya melebihi [maxDimension]. Rasio aspek dipertahankan.
  ///
  /// Bila kedua sisi sudah <= [maxDimension], objek aslinya dikembalikan
  /// tanpa salinan.
  img.Image _resizeIfNeeded(img.Image image) {
    final int w = image.width;
    final int h = image.height;
    if (w <= maxDimension && h <= maxDimension) {
      return image;
    }

    if (w >= h) {
      // Landscape atau persegi: batasi lebar.
      return img.copyResize(
        image,
        width: maxDimension,
        interpolation: img.Interpolation.linear,
      );
    } else {
      // Portrait: batasi tinggi.
      return img.copyResize(
        image,
        height: maxDimension,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  /// Mengganti alpha channel pada [image] dengan latar belakang putih
  /// (#FFFFFF) sehingga output JPEG sepenuhnya opaque.
  ///
  /// Bila gambar tidak memiliki alpha channel, dikembalikan apa adanya.
  img.Image _flattenAlpha(img.Image image) {
    if (!image.hasAlpha) {
      return image;
    }

    // Buat kanvas putih solid berukuran sama, lalu komposisi gambar di atasnya.
    final img.Image background = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 3,
    );
    img.fill(background, color: img.ColorRgb8(255, 255, 255));
    return img.compositeImage(background, image);
  }
}
