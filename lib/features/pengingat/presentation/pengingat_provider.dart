import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/services/push/push_service.dart';
import '../../../core/services/push/push_service_provider.dart';
import '../data/pengingat_repository.dart';

part 'pengingat_provider.g.dart';

@riverpod
PengingatRepository pengingatRepository(Ref ref) =>
    PengingatRepository(ref.watch(apiClientProvider));

enum PengingatStatus {
  /// APK atau browser lama: notifikasi web tidak tersedia.
  unsupported,

  /// iPhone/iPad di tab browser: pasang di layar utama dulu.
  needsInstall,

  /// Server belum diisi kunci VAPID.
  serverDisabled,

  /// Izin notifikasi ditolak/diblokir.
  denied,

  /// Bisa diaktifkan.
  off,

  /// Aktif di perangkat ini.
  on,
}

class PengingatState {
  const PengingatState({
    required this.status,
    this.ios = false,
    this.config,
    this.bannerDismissed = true,
  });

  final PengingatStatus status;
  final bool ios;
  final PengingatConfig? config;

  /// Ajakan mengaktifkan pengingat di halaman Dokumentasi sudah ditutup.
  final bool bannerDismissed;

  /// Mis. "Senin–Jumat pukul 15.00".
  String get jadwal {
    final c = config;
    if (c == null) return 'setiap hari kerja';
    return '${c.daysLabel} pukul ${c.reminderTime.replaceAll(':', '.')}';
  }

  PengingatState copyWith({PengingatStatus? status, bool? bannerDismissed}) =>
      PengingatState(
        status: status ?? this.status,
        ios: ios,
        config: config,
        bannerDismissed: bannerDismissed ?? this.bannerDismissed,
      );
}

/// Pengingat harian (notifikasi web) untuk perangkat ini.
@riverpod
class PengingatNotifier extends _$PengingatNotifier {
  static const bannerKey = 'pengingat_banner_ditutup';

  @override
  Future<PengingatState> build() async {
    final device = await ref.read(pushServiceProvider).info();
    final dismissed = await _bannerDismissed();
    if (device.needsInstall) {
      return PengingatState(
          status: PengingatStatus.needsInstall,
          ios: true,
          bannerDismissed: dismissed);
    }
    if (!device.supported) {
      return const PengingatState(status: PengingatStatus.unsupported);
    }

    final repo = ref.read(pengingatRepositoryProvider);
    final config = await repo.getConfig();
    PengingatState result(PengingatStatus status) => PengingatState(
        status: status,
        ios: device.ios,
        config: config,
        bannerDismissed: dismissed);

    if (!config.enabled || config.publicKey == null) {
      return result(PengingatStatus.serverDisabled);
    }
    if (device.permission == 'denied') return result(PengingatStatus.denied);

    final subscription = device.subscription;
    final sameKey =
        device.serverKey == null || device.serverKey == config.publicKey;
    if (subscription != null && device.permission == 'granted' && sameKey) {
      // Pastikan server mengaitkan langganan ini dengan sesi login sekarang
      // (mis. sesi lama sudah kedaluwarsa lalu login ulang).
      try {
        await repo.subscribe(subscription);
      } catch (_) {}
      return result(PengingatStatus.on);
    }
    return result(PengingatStatus.off);
  }

  Future<bool> _bannerDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(bannerKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Aktifkan pengingat. Panggil langsung dari ketukan pengguna.
  /// Mengembalikan `null` bila berhasil, atau pesan error.
  Future<String?> aktifkan() async {
    final current = state.valueOrNull;
    final key = current?.config?.publicKey;
    if (current == null || key == null) return 'Coba lagi sebentar.';

    // Minta izin & berlangganan sebelum ada await lain (wajib di iPhone).
    final PushSubscriptionData subscription;
    try {
      subscription = await ref.read(pushServiceProvider).subscribe(key);
    } on PushException catch (e) {
      if (e.denied) {
        state = AsyncData(current.copyWith(status: PengingatStatus.denied));
      }
      return e.message;
    }
    try {
      await ref.read(pengingatRepositoryProvider).subscribe(subscription);
    } catch (e) {
      return e.toString();
    }
    state = AsyncData(
        current.copyWith(status: PengingatStatus.on, bannerDismissed: true));
    return null;
  }

  /// Matikan pengingat di perangkat ini. `null` bila berhasil.
  Future<String?> matikan() async {
    final current = state.valueOrNull;
    if (current == null) return null;
    try {
      final endpoint = await ref.read(pushServiceProvider).unsubscribe();
      if (endpoint != null) {
        // Bila gagal, server menghapusnya sendiri saat pengiriman berikutnya
        // ditolak layanan push.
        try {
          await ref.read(pengingatRepositoryProvider).unsubscribe(endpoint);
        } catch (_) {}
      }
    } on PushException catch (e) {
      return e.message;
    }
    state = AsyncData(current.copyWith(status: PengingatStatus.off));
    return null;
  }

  /// Kirim notifikasi uji ke perangkat ini. `null` bila berhasil.
  Future<String?> kirimUji() async {
    try {
      await ref.read(pengingatRepositoryProvider).sendTest();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> tutupBanner() async {
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(bannerDismissed: true));
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(bannerKey, true);
    } catch (_) {}
  }
}
