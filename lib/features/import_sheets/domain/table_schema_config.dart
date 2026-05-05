import 'column_mapping_model.dart';

const Map<String, List<ColumnDefinition>> kSupabaseTableSchemas = {
  'users': [
    ColumnDefinition(name: 'nama', type: 'text', required: true),
    ColumnDefinition(name: 'email', type: 'text', required: true),
    ColumnDefinition(name: 'jabatan', type: 'text', required: false),
    ColumnDefinition(name: 'unit_kerja', type: 'text', required: false),
    ColumnDefinition(name: 'role', type: 'text', required: true),
  ],
  'kegiatan': [
    ColumnDefinition(name: 'judul', type: 'text', required: true),
    ColumnDefinition(name: 'deskripsi', type: 'text', required: false),
    ColumnDefinition(name: 'deadline', type: 'date', required: true),
  ],
  'laporan': [
    ColumnDefinition(name: 'user_id', type: 'uuid', required: true),
    ColumnDefinition(name: 'catatan', type: 'text', required: false),
    ColumnDefinition(
      name: 'image_url',
      type: 'text',
      required: false, // URL Drive as-is dari spreadsheet
    ),
    ColumnDefinition(name: 'created_at', type: 'timestamp', required: false),
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
