import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/presentation/auth_provider.dart';

// GlobalKey untuk mengakses drawer dari mana saja di admin area
final adminScaffoldKey = GlobalKey<ScaffoldState>();

class AdminScaffold extends ConsumerWidget {
  final Widget child;

  const AdminScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return _WideLayout(child: child);
    } else {
      return _NarrowLayout(child: child);
    }
  }
}

class _WideLayout extends ConsumerWidget {
  final Widget child;

  const _WideLayout({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 240,
            child: _AdminSidebar(currentLocation: location),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NarrowLayout extends ConsumerWidget {
  final Widget child;

  const _NarrowLayout({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      key: adminScaffoldKey,
      drawer: Drawer(
        child: _AdminSidebar(currentLocation: location),
      ),
      body: child,
    );
  }
}

class _AdminSidebar extends ConsumerWidget {
  final String currentLocation;

  const _AdminSidebar({required this.currentLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;

    return Container(
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset('assets/images/Logo-BPS.png',
                      width: 48, height: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'PantauPegawai',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (user != null)
                    Text(
                      user.nama,
                      style: const TextStyle(
                        color: AppColors.sidebarTextInactive,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),

          // Nav items
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: '/admin/dashboard',
            isActive: currentLocation == '/admin/dashboard',
          ),
          _NavItem(
            icon: Icons.people_outline,
            label: 'Pegawai',
            route: '/admin/pegawai',
            isActive: currentLocation.startsWith('/admin/pegawai'),
          ),
          _NavItem(
            icon: Icons.assignment_outlined,
            label: 'Proyek',
            route: '/admin/kegiatan',
            isActive: currentLocation.startsWith('/admin/kegiatan'),
          ),
          _NavItem(
            icon: Icons.photo_library_outlined,
            label: 'Dokumentasi',
            route: '/admin/dokumentasi',
            isActive: currentLocation.startsWith('/admin/dokumentasi'),
          ),
          _NavItem(
            icon: Icons.bar_chart_outlined,
            label: 'Rekap Upload',
            route: '/admin/rekap-upload',
            isActive: currentLocation.startsWith('/admin/rekap-upload'),
          ),
          _NavItem(
            icon: Icons.upload_file_outlined,
            label: 'Import Data',
            route: '/admin/import-sheets',
            isActive: currentLocation.startsWith('/admin/import-sheets'),
          ),

          const Spacer(),
          const Divider(color: Colors.white24, height: 1),

          // Logout
          ListTile(
            leading:
                const Icon(Icons.logout, color: AppColors.sidebarTextInactive),
            title: const Text(
              'Keluar',
              style: TextStyle(color: AppColors.sidebarTextInactive),
            ),
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? Colors.white : AppColors.sidebarTextInactive,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.sidebarTextInactive,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          // Tutup drawer hanya jika sedang terbuka (mode mobile)
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold != null && scaffold.isDrawerOpen) {
            Navigator.of(context).pop();
          }
          context.go(route);
        },
        dense: true,
      ),
    );
  }
}

/// Mixin/helper untuk menambahkan hamburger button dan logout di AppBar admin
/// saat mode mobile. Gunakan di setiap screen admin.
///
/// Contoh penggunaan:
/// ```dart
/// appBar: AppBar(
///   title: const Text('Dashboard'),
///   leading: AdminMenuButton(),
///   actions: [
///     AdminLogoutButton(),
///     IconButton(icon: Icon(Icons.refresh), onPressed: ...),
///   ],
/// ),
/// ```
class AdminMenuButton extends ConsumerWidget {
  const AdminMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    if (isWide) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: () => adminScaffoldKey.currentState?.openDrawer(),
    );
  }
}

class AdminLogoutButton extends ConsumerWidget {
  const AdminLogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    if (isWide) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Keluar',
      onPressed: () async {
        await ref.read(authNotifierProvider.notifier).logout();
        if (context.mounted) context.go('/login');
      },
    );
  }
}
