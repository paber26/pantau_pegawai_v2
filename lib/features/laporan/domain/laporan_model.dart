class LaporanModel {
  final String id;
  final String userId;
  final String kegiatanId;
  final String imageUrl;
  final String? deskripsi;
  final DateTime createdAt;

  // Join fields
  final String? pegawaiNama;
  final String? kegiatanJudul;

  const LaporanModel({
    required this.id,
    required this.userId,
    required this.kegiatanId,
    required this.imageUrl,
    this.deskripsi,
    required this.createdAt,
    this.pegawaiNama,
    this.kegiatanJudul,
  });

  factory LaporanModel.fromMap(Map<String, dynamic> map) {
    return LaporanModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      kegiatanId: map['kegiatan_id'] as String,
      imageUrl: map['image_url'] as String,
      deskripsi: map['deskripsi'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      pegawaiNama: map['users'] != null
          ? (map['users'] as Map<String, dynamic>)['nama'] as String?
          : null,
      kegiatanJudul: map['kegiatan'] != null
          ? (map['kegiatan'] as Map<String, dynamic>)['judul'] as String?
          : null,
    );
  }
}
