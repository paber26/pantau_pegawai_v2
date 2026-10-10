import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/network_providers.dart';
import '../domain/dashboard_stats_model.dart';

part 'dashboard_provider.g.dart';

/// Statistik dihitung di server dengan COUNT (tidak terbatas 1000 baris).
/// "Belum upload" = pegawai tanpa dokumentasi bertanggal hari ini (WITA).
@riverpod
Future<DashboardStatsModel> dashboardStats(Ref ref) async {
  final data = await ref.read(apiClientProvider).get('/api/dashboard/stats');
  return DashboardStatsModel.fromMap(data as Map<String, dynamic>);
}
