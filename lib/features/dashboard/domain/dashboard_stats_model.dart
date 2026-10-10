class DashboardStatsModel {
  final int totalPegawai;
  final int jumlahProyek;
  final int totalDokumentasi;
  final int pegawaiBelumUpload;

  const DashboardStatsModel({
    required this.totalPegawai,
    required this.jumlahProyek,
    required this.totalDokumentasi,
    required this.pegawaiBelumUpload,
  });

  /// Dari respons `GET /api/dashboard/stats`.
  factory DashboardStatsModel.fromMap(Map<String, dynamic> map) {
    return DashboardStatsModel(
      totalPegawai: map['total_pegawai'] as int,
      jumlahProyek: map['jumlah_proyek'] as int,
      totalDokumentasi: map['total_dokumentasi'] as int,
      pegawaiBelumUpload: map['pegawai_belum_upload'] as int,
    );
  }
}
