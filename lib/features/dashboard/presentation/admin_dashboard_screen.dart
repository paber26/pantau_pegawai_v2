import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_utils.dart';
import '../../../shared/widgets/admin_scaffold.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../laporan/domain/laporan_model.dart';
import 'dashboard_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final recentAsync = ref.watch(recentLaporanProvider);

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
                        title: 'Kegiatan Aktif',
                        value: stats.kegiatanAktif.toString(),
                        icon: Icons.assignment_outlined,
                        color: AppColors.accent,
                        onTap: () => context.push('/admin/kegiatan'),
                      ),
                      StatCard(
                        title: 'Total Laporan',
                        value: stats.totalLaporan.toString(),
                        icon: Icons.description_outlined,
                        color: AppColors.success,
                        onTap: () => context.push('/admin/laporan'),
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

              const SizedBox(height: 24),

              // Laporan terbaru (realtime)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Laporan Terbaru',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/admin/laporan'),
                    child: const Text('Lihat Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              recentAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
                data: (list) => list.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Belum ada laporan'),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _RecentLaporanCard(laporan: list[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentLaporanCard extends StatelessWidget {
  final LaporanModel laporan;

  const _RecentLaporanCard({required this.laporan});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/admin/laporan/${laporan.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  laporan.imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: AppColors.background,
                    child: const Icon(Icons.image_outlined,
                        color: AppColors.textHint),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (laporan.pegawaiNama != null)
                      Text(
                        laporan.pegawaiNama!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    if (laporan.kegiatanJudul != null)
                      Text(
                        laporan.kegiatanJudul!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      AppDateUtils.formatDateTime(laporan.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              // Realtime indicator
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
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
