import '../../pegawai/domain/pegawai_model.dart';

class PenugasanModel {
  final String id;
  final String userId;
  final String kegiatanId;
  final DateTime createdAt;
  final PegawaiModel? pegawai;

  const PenugasanModel({
    required this.id,
    required this.userId,
    required this.kegiatanId,
    required this.createdAt,
    this.pegawai,
  });

  factory PenugasanModel.fromMap(Map<String, dynamic> map) {
    return PenugasanModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      kegiatanId: map['kegiatan_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      pegawai: map['users'] != null
          ? PegawaiModel.fromMap(map['users'] as Map<String, dynamic>)
          : null,
    );
  }
}
