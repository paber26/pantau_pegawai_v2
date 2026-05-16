import 'dart:typed_data';

/// Hasil dari operasi pembacaan clipboard untuk gambar.
///
/// Sealed class dengan beberapa varian yang merepresentasikan kemungkinan
/// hasil ketika [ClipboardService.readImageFromClipboard] dipanggil:
///
/// - [ClipboardImageSuccess]: Berhasil membaca data gambar dari clipboard.
/// - [ClipboardEmpty]: Clipboard kosong, tidak ada konten apapun.
/// - [ClipboardNoImage]: Clipboard berisi konten lain (misal teks) namun
///   bukan gambar.
/// - [ClipboardCorruptImage]: Data gambar di clipboard tidak dapat
///   di-decode sebagai PNG, JPEG, atau WEBP.
/// - [ClipboardPermissionDenied]: Platform menolak akses ke clipboard.
/// - [ClipboardUnsupported]: Platform/browser tidak mendukung pembacaan
///   gambar dari clipboard.
sealed class ClipboardReadResult {
  const ClipboardReadResult();
}

/// Hasil sukses: clipboard berisi gambar yang valid dan dapat di-decode.
///
/// [imageBytes] berisi byte mentah gambar dalam format PNG, JPEG, atau
/// WEBP, persis seperti yang dibaca dari clipboard tanpa transformasi.
class ClipboardImageSuccess extends ClipboardReadResult {
  final Uint8List imageBytes;

  const ClipboardImageSuccess(this.imageBytes);
}

/// Clipboard kosong saat operasi paste dipicu.
class ClipboardEmpty extends ClipboardReadResult {
  const ClipboardEmpty();
}

/// Clipboard berisi konten non-gambar (misal teks atau file lain).
class ClipboardNoImage extends ClipboardReadResult {
  const ClipboardNoImage();
}

/// Clipboard berisi data yang seharusnya gambar, namun tidak dapat
/// di-decode sebagai PNG, JPEG, atau WEBP yang valid.
class ClipboardCorruptImage extends ClipboardReadResult {
  const ClipboardCorruptImage();
}

/// Platform menolak akses ke clipboard (mis. izin tidak diberikan).
class ClipboardPermissionDenied extends ClipboardReadResult {
  const ClipboardPermissionDenied();
}

/// Platform atau browser tidak mendukung pembacaan gambar dari clipboard.
class ClipboardUnsupported extends ClipboardReadResult {
  const ClipboardUnsupported();
}

/// Antarmuka platform-agnostic untuk membaca gambar dari clipboard sistem.
///
/// Implementasi konkret disediakan per-platform:
/// - `WebClipboardService` untuk web (browser Clipboard API).
/// - `NativeClipboardService` untuk desktop dan mobile (platform channel).
///
/// Konsumen biasanya mengakses service melalui Riverpod provider sehingga
/// platform yang sesuai dipilih otomatis.
abstract class ClipboardService {
  /// Membaca data gambar dari clipboard sistem.
  ///
  /// Mengembalikan [ClipboardReadResult] yang menunjukkan keberhasilan
  /// atau jenis kegagalan. Operasi ini memiliki batas waktu (timeout)
  /// 5 detik sesuai kebutuhan; jika timeout terlampaui, implementasi
  /// SHALL mengembalikan [ClipboardCorruptImage].
  Future<ClipboardReadResult> readImageFromClipboard();

  /// Apakah pembacaan gambar dari clipboard didukung pada platform saat ini.
  ///
  /// Pada web, ini mengecek ketersediaan `navigator.clipboard.read` API.
  /// Pada platform native, biasanya selalu `true` sehingga tombol paste
  /// tetap ditampilkan.
  bool get isSupported;
}
