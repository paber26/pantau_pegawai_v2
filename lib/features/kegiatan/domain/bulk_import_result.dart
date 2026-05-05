/// Hasil dari operasi bulk import kegiatan.
class BulkImportResult {
  /// Jumlah proyek yang berhasil diinsert ke database.
  final int inserted;

  /// Jumlah proyek yang dilewati karena sudah ada di database.
  final int skipped;

  const BulkImportResult({
    required this.inserted,
    required this.skipped,
  });
}
