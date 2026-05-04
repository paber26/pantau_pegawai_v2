class AppAuthUser {
  final String id;
  final String nama;
  final String email;
  final String? jabatan;
  final String? unitKerja;
  final String role;

  const AppAuthUser({
    required this.id,
    required this.nama,
    required this.email,
    this.jabatan,
    this.unitKerja,
    required this.role,
  });

  bool get isAdmin => role == 'admin';

  factory AppAuthUser.fromMap(Map<String, dynamic> map) {
    return AppAuthUser(
      id: map['id'] as String,
      nama: map['nama'] as String,
      email: map['email'] as String,
      jabatan: map['jabatan'] as String?,
      unitKerja: map['unit_kerja'] as String?,
      role: map['role'] as String? ?? 'pegawai',
    );
  }
}
