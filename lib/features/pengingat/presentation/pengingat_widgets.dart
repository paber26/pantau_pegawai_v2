import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import 'pengingat_provider.dart';

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.error : AppColors.success,
  ));
}

/// Langkah memasang Pawai di layar utama iPhone (syarat notifikasi web iOS).
const _caraPasangIphone =
    'Buka Pawai di Safari → Bagikan → Tambah ke Layar Utama, lalu buka Pawai dari ikon itu.';

String _keterangan(PengingatState s) {
  switch (s.status) {
    case PengingatStatus.on:
      return 'Aktif. Diingatkan ${s.jadwal} bila belum ada dokumentasi hari itu.';
    case PengingatStatus.off:
      return 'Ingatkan saya ${s.jadwal} bila belum ada dokumentasi hari itu.';
    case PengingatStatus.needsInstall:
      return 'Di iPhone, pengingat hanya bisa setelah Pawai dipasang di layar utama. $_caraPasangIphone';
    case PengingatStatus.denied:
      return s.ios
          ? 'Notifikasi diblokir. Izinkan di Pengaturan → Notifikasi → Pawai.'
          : 'Notifikasi diblokir. Izinkan lewat ikon gembok di samping alamat situs → Notifikasi.';
    case PengingatStatus.serverDisabled:
      return 'Belum diaktifkan oleh admin.';
    case PengingatStatus.unsupported:
      return 'Tidak tersedia di perangkat ini. Buka Pawai lewat browser (Chrome/Safari).';
  }
}

/// Pengaturan "Pengingat Harian" di sheet Profil.
class PengingatTile extends ConsumerStatefulWidget {
  const PengingatTile({super.key});

  @override
  ConsumerState<PengingatTile> createState() => _PengingatTileState();
}

class _PengingatTileState extends ConsumerState<PengingatTile> {
  bool _busy = false;

  /// Hasil aksi terakhir, ditampilkan di dalam tile (snackbar akan tertutup
  /// sheet Profil).
  String? _pesan;
  bool _pesanError = false;

  Future<void> _run(Future<String?> Function() action, String sukses) async {
    setState(() {
      _busy = true;
      _pesan = null;
    });
    final error = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pesan = error ?? sukses;
      _pesanError = error != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pengingatNotifierProvider);
    final notifier = ref.read(pengingatNotifierProvider.notifier);
    final s = async.valueOrNull;
    final bisaDiubah = s != null &&
        (s.status == PengingatStatus.on || s.status == PengingatStatus.off);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                s?.status == PengingatStatus.on
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Pengingat Harian',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (_busy || async.isLoading)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (bisaDiubah)
                Switch(
                  value: s.status == PengingatStatus.on,
                  onChanged: (aktif) => _run(
                    aktif ? notifier.aktifkan : notifier.matikan,
                    aktif ? 'Pengingat harian aktif' : 'Pengingat harian dimatikan',
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 8, bottom: 4),
            child: Text(
              async.hasError
                  ? 'Gagal memuat pengaturan pengingat.'
                  : s == null
                      ? 'Memuat…'
                      : _keterangan(s),
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          if (_pesan != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, right: 8, bottom: 4),
              child: Text(
                _pesan!,
                style: TextStyle(
                    fontSize: 12,
                    color: _pesanError ? AppColors.error : AppColors.success),
              ),
            ),
          if (s?.status == PengingatStatus.on && !_busy)
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: TextButton.icon(
                onPressed: () => _run(notifier.kirimUji,
                    'Notifikasi uji dikirim. Cek notifikasi perangkat ini.'),
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('Kirim notifikasi uji'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ajakan mengaktifkan pengingat di atas daftar Dokumentasi Harian.
/// Tidak tampil bila sudah aktif, tidak didukung, atau pernah ditutup.
class PengingatBanner extends ConsumerStatefulWidget {
  const PengingatBanner({super.key});

  @override
  ConsumerState<PengingatBanner> createState() => _PengingatBannerState();
}

class _PengingatBannerState extends ConsumerState<PengingatBanner> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(pengingatNotifierProvider).valueOrNull;
    final notifier = ref.read(pengingatNotifierProvider.notifier);
    if (s == null ||
        s.bannerDismissed ||
        (s.status != PengingatStatus.off &&
            s.status != PengingatStatus.needsInstall)) {
      return const SizedBox.shrink();
    }
    final perluPasang = s.status == PengingatStatus.needsInstall;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: AppColors.primary.withValues(alpha: 0.06),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined,
                    color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    perluPasang
                        ? 'Ingin diingatkan bila belum upload dokumentasi? '
                            '$_caraPasangIphone'
                        : 'Aktifkan pengingat harian? Anda akan diingatkan '
                            '${s.jadwal} bila belum ada dokumentasi hari itu.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  TextButton(
                    onPressed: _busy ? null : notifier.tutupBanner,
                    child: Text(perluPasang ? 'Mengerti' : 'Nanti'),
                  ),
                  if (!perluPasang)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              final error = await notifier.aktifkan();
                              if (!mounted || !context.mounted) return;
                              setState(() => _busy = false);
                              _snack(context, error ?? 'Pengingat harian aktif',
                                  error: error != null);
                            },
                      child: const Text('Aktifkan'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
