class DokumentasiModel {
  final String id;
  final String userId;
  final String proyek;
  final DateTime tanggalKegiatan;
  final String? imageUrl;
  final String? catatan;
  final String? link;
  final DateTime createdAt;

  // Join fields
  final String? pegawaiNama;

  const DokumentasiModel({
    required this.id,
    required this.userId,
    required this.proyek,
    required this.tanggalKegiatan,
    this.imageUrl,
    this.catatan,
    this.link,
    required this.createdAt,
    this.pegawaiNama,
  });

  factory DokumentasiModel.fromMap(Map<String, dynamic> map) {
    return DokumentasiModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      proyek: map['proyek'] as String,
      tanggalKegiatan: DateTime.parse(map['tanggal_kegiatan'] as String),
      imageUrl: map['image_url'] as String?,
      catatan: map['catatan'] as String?,
      link: map['link'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      pegawaiNama: map['users'] != null
          ? (map['users'] as Map<String, dynamic>)['nama'] as String?
          : null,
    );
  }
}
