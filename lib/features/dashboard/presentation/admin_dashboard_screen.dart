import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/admin_scaffold.dart';
import '../../../shared/widgets/stat_card.dart';
import 'dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: const AdminMenuButton(),
        actions: [
          const AdminLogoutButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats grid
              statsAsync.when(
                loading: () => const _StatsShimmer(),
                error: (e, _) => Text('Error: $e'),
                data: (stats) {
                  // Hitung aspect ratio berdasarkan lebar layar
                  // Layar sempit butuh rasio lebih besar agar konten tidak overflow
                  final screenWidth = MediaQuery.of(context).size.width;
                  final cardWidth =
                      (screenWidth - 32 - 12) / 2; // padding + gap
                  final aspectRatio = cardWidth < 150 ? 1.6 : 1.4;

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: aspectRatio,
                    children: [
                      StatCard(
                        title: 'Total Pegawai',
                        value: stats.totalPegawai.toString(),
                        icon: Icons.people_outline,
                        color: AppColors.primary,
                        onTap: () => context.push('/admin/pegawai'),
                      ),
                      StatCard(
                        title: 'Jumlah Proyek',
                        value: stats.jumlahProyek.toString(),
                        icon: Icons.folder_outlined,
                        color: AppColors.accent,
                        onTap: () => context.push('/admin/kegiatan'),
                      ),
                      StatCard(
                        title: 'Total Dokumentasi',
                        value: stats.totalDokumentasi.toString(),
                        icon: Icons.photo_library_outlined,
                        color: AppColors.success,
                        onTap: () => context.push('/admin/dokumentasi'),
                      ),
                      StatCard(
                        title: 'Belum Upload',
                        value: stats.pegawaiBelumUpload.toString(),
                        icon: Icons.warning_amber_outlined,
                        color: AppColors.warning,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 32 - 12) / 2;
    final aspectRatio = cardWidth < 150 ? 1.6 : 1.4;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: aspectRatio,
      children: List.generate(
        4,
        (_) => Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
