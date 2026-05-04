class PegawaiModel {
  final String id;
  final String nama;
  final String email;
  final String? jabatan;
  final String? unitKerja;
  final String role;
  final DateTime createdAt;

  const PegawaiModel({
    required this.id,
    required this.nama,
    required this.email,
    this.jabatan,
    this.unitKerja,
    required this.role,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory PegawaiModel.fromMap(Map<String, dynamic> map) {
    return PegawaiModel(
      id: map['id'] as String,
      nama: map['nama'] as String,
      email: map['email'] as String,
      jabatan: map['jabatan'] as String?,
      unitKerja: map['unit_kerja'] as String?,
      role: map['role'] as String? ?? 'pegawai',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'email': email,
      'jabatan': jabatan,
      'unit_kerja': unitKerja,
      'role': role,
    };
  }

  PegawaiModel copyWith({
    String? nama,
    String? email,
    String? jabatan,
    String? unitKerja,
    String? role,
  }) {
    return PegawaiModel(
      id: id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      jabatan: jabatan ?? this.jabatan,
      unitKerja: unitKerja ?? this.unitKerja,
      role: role ?? this.role,
      createdAt: createdAt,
    );
  }
}
