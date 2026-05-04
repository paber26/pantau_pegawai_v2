import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dashboard_stats_model.dart';
import '../../laporan/domain/laporan_model.dart';

part 'dashboard_provider.g.dart';

@riverpod
Future<DashboardStatsModel> dashboardStats(Ref ref) async {
  final client = Supabase.instance.client;

  // Jalankan semua query secara paralel
  final results = await Future.wait([
    client.from('users').select('id').eq('role', 'pegawai'),
    client
        .from('kegiatan')
        .select('id')
        .gte('deadline', DateTime.now().toIso8601String().split('T').first),
    client.from('laporan').select('id'),
  ]);

  final allPegawai = results[0] as List;
  final kegiatanAktif = results[1] as List;
  final allLaporan = results[2] as List;

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
    kegiatanAktif: kegiatanAktif.length,
    totalLaporan: allLaporan.length,
    pegawaiBelumUpload: belumUpload,
  );
}

/// Stream laporan terbaru untuk realtime update
@riverpod
Stream<List<LaporanModel>> recentLaporan(Ref ref) {
  final client = Supabase.instance.client;

  return client
      .from('laporan')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(10)
      .map((data) => data.map((e) => LaporanModel.fromMap(e)).toList());
}
