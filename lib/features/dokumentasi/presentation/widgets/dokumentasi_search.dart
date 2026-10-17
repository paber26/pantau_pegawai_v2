import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/dokumentasi_model.dart';

/// Kata-kata pencarian: huruf kecil, dipisah spasi.
List<String> kataPencarian(String query) => query
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((k) => k.isNotEmpty)
    .toList();

/// Dokumentasi cocok bila **semua** kata ada di catatan, kegiatan, atau nama
/// pegawai (urutan bebas, huruf besar/kecil tidak dibedakan). Jadi
/// "monitoring kondisi usaha" menemukan catatan "Membuat monitoring SE
/// kondisi usaha dan keluarga yang ditemukan".
bool cocokPencarian(DokumentasiModel doc, List<String> kata) {
  if (kata.isEmpty) return true;
  final teks = '${doc.catatan ?? ''} ${doc.proyek} ${doc.pegawaiNama ?? ''}'
      .toLowerCase();
  return kata.every(teks.contains);
}

List<DokumentasiModel> saringPencarian(
    List<DokumentasiModel> list, String query) {
  final kata = kataPencarian(query);
  if (kata.isEmpty) return list;
  return list.where((d) => cocokPencarian(d, kata)).toList();
}

/// Teks dengan kata pencarian ditandai (latar kuning, tebal).
class HighlightText extends StatelessWidget {
  const HighlightText(
    this.text, {
    super.key,
    required this.query,
    this.style,
    this.maxLines,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;

  /// Bagian teks berurutan; `true` = cocok dengan salah satu kata.
  static List<(String, bool)> bagian(String text, List<String> kata) {
    final lower = text.toLowerCase();
    // toLowerCase bisa mengubah panjang untuk huruf tertentu; jangan tandai.
    if (kata.isEmpty || lower.length != text.length) return [(text, false)];
    final cocok = List<bool>.filled(text.length, false);
    for (final k in kata) {
      for (var i = lower.indexOf(k); i >= 0; i = lower.indexOf(k, i + 1)) {
        cocok.fillRange(i, i + k.length, true);
      }
    }
    final hasil = <(String, bool)>[];
    var awal = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i == text.length || cocok[i] != cocok[awal]) {
        hasil.add((text.substring(awal, i), cocok[awal]));
        awal = i;
      }
    }
    return hasil;
  }

  @override
  Widget build(BuildContext context) {
    final kata = kataPencarian(query);
    if (kata.isEmpty) {
      return Text(text,
          style: style,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(children: [
        for (final (potongan, cocok) in bagian(text, kata))
          TextSpan(
            text: potongan,
            style: cocok
                ? const TextStyle(
                    backgroundColor: Color(0xFFFFE082),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)
                : null,
          ),
      ]),
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}

/// Kolom pencarian di atas daftar dokumentasi.
class DokSearchField extends StatefulWidget {
  const DokSearchField({
    super.key,
    required this.onChanged,
    this.jumlahHasil,
    this.hintText = 'Cari catatan, kegiatan, atau nama…',
  });

  final ValueChanged<String> onChanged;
  final String hintText;

  /// Jumlah dokumentasi yang cocok; ditampilkan saat ada kata pencarian.
  final int? jumlahHasil;

  @override
  State<DokSearchField> createState() => _DokSearchFieldState();
}

class _DokSearchFieldState extends State<DokSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final adaKata = _controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          widget.onChanged(value);
          setState(() {});
        },
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: adaKata
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  if (widget.jumlahHasil != null)
                    Text('${widget.jumlahHasil} hasil',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  IconButton(
                    tooltip: 'Hapus pencarian',
                    icon: const Icon(Icons.close),
                    onPressed: _clear,
                  ),
                ])
              : null,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
        ),
      ),
    );
  }
}

/// Isi halaman saat pencarian tidak menemukan apa pun.
class DokSearchEmpty extends StatelessWidget {
  const DokSearchEmpty({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off, size: 56, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('Tidak ada dokumentasi yang cocok dengan "${query.trim()}".',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
