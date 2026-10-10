import 'column_mapping_model.dart';

/// Tabel & kolom yang bisa diimpor (harus sama dengan whitelist di
/// server/src/routes/import.ts). Akun pegawai ditambah lewat menu Pegawai.
const Map<String, List<ColumnDefinition>> kImportTableSchemas = {
  'kegiatan': [
    ColumnDefinition(name: 'judul', type: 'text', required: true),
    ColumnDefinition(name: 'deskripsi', type: 'text', required: false),
    ColumnDefinition(name: 'deadline', type: 'date', required: true),
  ],
  'dokumentasi': [
    ColumnDefinition(name: 'user_id', type: 'uuid', required: true),
    ColumnDefinition(name: 'proyek', type: 'text', required: true),
    ColumnDefinition(name: 'tanggal_kegiatan', type: 'date', required: true),
    ColumnDefinition(name: 'catatan', type: 'text', required: false),
    ColumnDefinition(name: 'link', type: 'text', required: false),
    ColumnDefinition(
      name: 'image_url',
      type: 'text',
      required: false, // URL Drive as-is dari spreadsheet
    ),
  ],
};
