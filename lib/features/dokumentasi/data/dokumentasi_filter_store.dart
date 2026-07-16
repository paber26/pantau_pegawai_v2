import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Nilai filter dokumentasi yang dipertahankan antar sesi.
///
/// Disimpan ke penyimpanan lokal (localStorage di web, SharedPreferences di
/// mobile) supaya filter tetap diterapkan setelah halaman di-refresh, alih-alih
/// mengharuskan pengguna memfilter ulang dari awal.
class DokumentasiFilter {
  final String? pegawaiId;
  final String? proyek;
  final DateTime? from;
  final DateTime? to;

  const DokumentasiFilter({
    this.pegawaiId,
    this.proyek,
    this.from,
    this.to,
  });

  static const empty = DokumentasiFilter();

  bool get isEmpty =>
      pegawaiId == null && proyek == null && from == null && to == null;

  Map<String, dynamic> toJson() => {
        'pegawaiId': pegawaiId,
        'proyek': proyek,
        'from': from?.toIso8601String(),
        'to': to?.toIso8601String(),
      };

  factory DokumentasiFilter.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? v) =>
        v is String ? DateTime.tryParse(v) : null;
    return DokumentasiFilter(
      pegawaiId: json['pegawaiId'] as String?,
      proyek: json['proyek'] as String?,
      from: parse(json['from']),
      to: parse(json['to']),
    );
  }
}

/// Menyimpan & memuat [DokumentasiFilter] ke penyimpanan lokal.
class DokumentasiFilterStore {
  DokumentasiFilterStore._();

  static const _key = 'dokumentasi_filter';

  static Future<DokumentasiFilter> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return DokumentasiFilter.empty;
      return DokumentasiFilter.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Penyimpanan korup / tidak tersedia — mulai tanpa filter.
      return DokumentasiFilter.empty;
    }
  }

  static Future<void> save(DokumentasiFilter filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (filter.isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(filter.toJson()));
      }
    } catch (_) {
      // Abaikan kegagalan penyimpanan; filter tetap berlaku untuk sesi ini.
    }
  }
}
