import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/features/dokumentasi/domain/dokumentasi_model.dart';

Map<String, dynamic> _row([Map<String, dynamic> extra = const {}]) => {
      'id': 'd1',
      'user_id': 'u1',
      'pegawai_nama': 'Budi Santoso',
      'proyek': 'Sakernas',
      'tanggal_kegiatan': '2026-10-11',
      'created_at': '2026-10-11T02:00:00.000Z',
      'users': {'nama': 'Budi Santoso', 'jabatan': null, 'unit_kerja': null},
      ...extra,
    };

void main() {
  test('dokumentasi aktif: deletedAt dan deletedByNama kosong', () {
    final doc = DokumentasiModel.fromMap(
        _row({'deleted_at': null, 'deleted_by_nama': null}));
    expect(doc.deletedAt, isNull);
    expect(doc.deletedByNama, isNull);
  });

  test('dokumentasi terhapus: membaca waktu dan nama penghapus', () {
    final doc = DokumentasiModel.fromMap(_row({
      'deleted_at': '2026-10-12T01:30:00.000Z',
      'deleted_by_nama': 'Budi Santoso',
    }));
    expect(doc.deletedAt, DateTime.utc(2026, 10, 12, 1, 30));
    expect(doc.deletedByNama, 'Budi Santoso');
  });

  test('respons dari server lama (tanpa kolom hapus) tetap terbaca', () {
    final doc = DokumentasiModel.fromMap(_row());
    expect(doc.deletedAt, isNull);
    expect(doc.proyek, 'Sakernas');
  });
}
