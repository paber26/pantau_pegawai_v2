import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/admin_dashboard_screen.dart';
import '../../features/import_sheets/presentation/import_sheets_screen.dart';
import '../../features/dokumentasi/presentation/dokumentasi_screen.dart';
import '../../features/dokumentasi/presentation/admin_dokumentasi_screen.dart';
import '../../features/kegiatan/presentation/kegiatan_form_screen.dart';
import '../../features/kegiatan/presentation/kegiatan_list_screen.dart';
import '../../features/laporan/presentation/laporan_detail_screen.dart';
import '../../features/laporan/presentation/laporan_list_screen.dart';
import '../../features/pegawai/presentation/pegawai_form_screen.dart';
import '../../features/pegawai/presentation/pegawai_list_screen.dart';
import '../../features/penugasan/presentation/assign_screen.dart';
import '../../features/rekap_upload/presentation/rekap_upload_screen.dart';
import '../../shared/widgets/admin_scaffold.dart';
import '../../shared/widgets/pegawai_scaffold.dart';

part 'app_router.g.dart';

/// Memberi tahu [GoRouter] untuk mengevaluasi ulang `redirect` setiap kali
/// status auth berubah, tanpa perlu membuat ulang instance [GoRouter] itu
/// sendiri (lihat catatan di [appRouter]).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Provider ini sengaja TIDAK melakukan `ref.watch(authStateProvider)`.
  // Jika di-watch, setiap kali stream auth emit nilai baru (mis. sesaat
  // setelah refresh halaman ketika sesi baru selesai dipulihkan) provider
  // ini akan rebuild dan mengembalikan instance GoRouter yang BARU —
  // sehingga MaterialApp.router mengganti seluruh Router dan lokasi URL
  // saat ini (mis. /pegawai/riwayat) hilang, kembali ke initialLocation.
  //
  // Sebagai gantinya, instance GoRouter dipertahankan (keepAlive) selama
  // sesi aplikasi, dan `redirect` dievaluasi ulang lewat refreshListenable
  // setiap ada perubahan auth, sambil tetap membaca status auth terbaru
  // via `ref.read` di dalam callback.
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      // Status auth belum diketahui (mis. sesi masih dipulihkan setelah
      // refresh halaman) — jangan redirect dulu, tunggu sampai resolve
      // supaya lokasi URL saat ini tidak keburu digeser ke /login.
      if (authState.isLoading && !authState.hasValue) return null;

      final isLoggedIn = authState.valueOrNull != null;
      final isLoginPage = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginPage) return '/login';
      if (isLoggedIn && isLoginPage) {
        final role = authState.valueOrNull?.role ?? 'pegawai';
        // Pegawai langsung ke dokumentasi harian
        return role == 'admin' ? '/admin/dashboard' : '/pegawai/dokumentasi';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Admin routes ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminScaffold(child: child),
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/admin/pegawai',
            builder: (context, state) => const PegawaiListScreen(),
          ),
          GoRoute(
            path: '/admin/pegawai/tambah',
            builder: (context, state) => const PegawaiFormScreen(),
          ),
          GoRoute(
            path: '/admin/pegawai/:id/edit',
            builder: (context, state) =>
                PegawaiFormScreen(pegawaiId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/admin/kegiatan',
            builder: (context, state) =>
                const KegiatanListScreen(isAdmin: true),
          ),
          GoRoute(
            path: '/admin/kegiatan/tambah',
            builder: (context, state) => const KegiatanFormScreen(),
          ),
          GoRoute(
            path: '/admin/kegiatan/:id/edit',
            builder: (context, state) =>
                KegiatanFormScreen(kegiatanId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/admin/kegiatan/:id/assign',
            builder: (context, state) =>
                AssignScreen(kegiatanId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/admin/laporan',
            builder: (context, state) => const LaporanListScreen(isAdmin: true),
          ),
          GoRoute(
            path: '/admin/laporan/:id',
            builder: (context, state) =>
                LaporanDetailScreen(laporanId: state.pathParameters['id']!),
          ),
          // Admin lihat semua dokumentasi
          GoRoute(
            path: '/admin/dokumentasi',
            builder: (context, state) => const AdminDokumentasiScreen(),
          ),
          GoRoute(
            path: '/admin/import-sheets',
            builder: (context, state) => const ImportSheetsScreen(),
          ),
          GoRoute(
            path: '/admin/rekap-upload',
            builder: (context, state) => const RekapUploadScreen(),
          ),
        ],
      ),

      // ── Pegawai routes ────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => PegawaiScaffold(child: child),
        routes: [
          GoRoute(
            path: '/pegawai/dokumentasi',
            builder: (context, state) => const DokumentasiScreen(),
          ),
          GoRoute(
            path: '/pegawai/riwayat',
            builder: (context, state) => const RiwayatDokumentasiScreen(),
          ),
          GoRoute(
            path: '/pegawai/riwayat/:id',
            builder: (context, state) =>
                LaporanDetailScreen(laporanId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}
