import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dashboard_stats_model.dart';

part 'dashboard_provider.g.dart';

@riverpod
Future<DashboardStatsModel> dashboardStats(Ref ref) async {
  final client = Supabase.instance.client;

  // Jalankan semua query secara paralel
  final results = await Future.wait([
    client.from('users').select('id').eq('role', 'pegawai'),
    client.from('kegiatan').select('id'), // semua proyek, tanpa filter
    client.from('dokumentasi').select('id'), // total dokumentasi
  ]);

  final allPegawai = results[0] as List;
  final allProyek = results[1] as List;
  final allDokumentasi = results[2] as List;

  // Hitung pegawai yang belum upload laporan hari ini
  final today = DateTime.now().toIso8601String().split('T').first;
  final laporanHariIni = await client
      .from('laporan')
      .select('user_id')
      .gte('created_at', '${today}T00:00:00')
      .lte('created_at', '${today}T23:59:59');

  final uploadedUserIds =
      (laporanHariIni as List).map((e) => e['user_id'] as String).toSet();
  final belumUpload = allPegawai
      .where((p) => !uploadedUserIds.contains(p['id'] as String))
      .length;

  return DashboardStatsModel(
    totalPegawai: allPegawai.length,
    jumlahProyek: allProyek.length,
    totalDokumentasi: allDokumentasi.length,
    pegawaiBelumUpload: belumUpload,
  );
}
