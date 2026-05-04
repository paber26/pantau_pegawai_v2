class KegiatanModel {
  final String id;
  final String judul;
  final String? deskripsi;
  final DateTime deadline;
  final DateTime createdAt;

  const KegiatanModel({
    required this.id,
    required this.judul,
    this.deskripsi,
    required this.deadline,
    required this.createdAt,
  });

  bool get isDeadlinePassed => DateTime.now().isAfter(deadline);

  factory KegiatanModel.fromMap(Map<String, dynamic> map) {
    return KegiatanModel(
      id: map['id'] as String,
      judul: map['judul'] as String,
      deskripsi: map['deskripsi'] as String?,
      deadline: DateTime.parse(map['deadline'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'judul': judul,
      'deskripsi': deskripsi,
      'deadline': deadline.toIso8601String().split('T').first,
    };
  }
}
