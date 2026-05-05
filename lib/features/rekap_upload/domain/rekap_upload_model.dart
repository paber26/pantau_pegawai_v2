/// Model rekapitulasi upload dokumentasi per pegawai.
class RekapUploadModel {
  /// ID user dari tabel `users`.
  final String userId;

  /// Nama lengkap pegawai.
  final String nama;

  /// Jabatan pegawai (opsional).
  final String? jabatan;

  /// Unit kerja pegawai (opsional).
  final String? unitKerja;

  /// Total dokumentasi yang diupload pada tahun yang dipilih.
  final int total;

  /// Breakdown jumlah upload per bulan.
  /// Key: bulan (1-12), Value: jumlah upload bulan tersebut.
  final Map<int, int> perBulan;

  const RekapUploadModel({
    required this.userId,
    required this.nama,
    this.jabatan,
    this.unitKerja,
    required this.total,
    required this.perBulan,
  });
}
