/// Notifikasi web (Web Push) untuk pengingat harian.
///
/// Di web, implementasinya memanggil `window.pawaiPush` (web/pawai_push.js).
/// Di APK/iOS native belum didukung: [PushDeviceInfo.unsupported].
abstract class PushService {
  /// Status notifikasi di perangkat/browser ini.
  Future<PushDeviceInfo> info();

  /// Minta izin notifikasi (bila belum) lalu berlangganan dengan kunci
  /// publik VAPID server. Harus dipanggil langsung dari ketukan pengguna,
  /// tanpa `await` lain sebelumnya (iPhone menolak permintaan izin di luar
  /// ketukan). Melempar [PushException].
  Future<PushSubscriptionData> subscribe(String publicKey);

  /// Berhenti berlangganan di perangkat ini. Mengembalikan endpoint yang
  /// dihapus, atau `null` bila memang belum berlangganan.
  Future<String?> unsubscribe();
}

class PushDeviceInfo {
  const PushDeviceInfo({
    required this.supported,
    required this.ios,
    required this.standalone,
    required this.permission,
    this.subscription,
    this.serverKey,
  });

  static const unsupported = PushDeviceInfo(
      supported: false, ios: false, standalone: false, permission: 'unsupported');

  factory PushDeviceInfo.fromJson(Map<String, dynamic> json) => PushDeviceInfo(
        supported: json['supported'] == true,
        ios: json['ios'] == true,
        standalone: json['standalone'] == true,
        permission: json['permission'] as String? ?? 'unsupported',
        subscription: json['subscription'] is Map<String, dynamic>
            ? PushSubscriptionData.fromJson(
                json['subscription'] as Map<String, dynamic>)
            : null,
        serverKey: json['serverKey'] as String?,
      );

  /// Browser punya Push API, Service Worker, dan Notification.
  final bool supported;
  final bool ios;

  /// Dibuka dari ikon layar utama (bukan tab browser).
  final bool standalone;

  /// `default`, `granted`, `denied`, atau `unsupported`.
  final String permission;

  /// Langganan yang sudah ada di perangkat ini.
  final PushSubscriptionData? subscription;

  /// Kunci server yang dipakai [subscription], bila diketahui browser.
  final String? serverKey;

  /// iPhone/iPad di tab browser: notifikasi web baru bisa setelah Pawai
  /// dipasang di layar utama dan dibuka dari ikonnya.
  bool get needsInstall => ios && !standalone;
}

class PushSubscriptionData {
  const PushSubscriptionData({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
  });

  factory PushSubscriptionData.fromJson(Map<String, dynamic> json) {
    final keys = (json['keys'] as Map?) ?? const {};
    return PushSubscriptionData(
      endpoint: json['endpoint'] as String,
      p256dh: keys['p256dh'] as String,
      auth: keys['auth'] as String,
    );
  }

  final String endpoint;
  final String p256dh;
  final String auth;

  Map<String, dynamic> toJson() => {
        'endpoint': endpoint,
        'keys': {'p256dh': p256dh, 'auth': auth},
      };
}

class PushException implements Exception {
  const PushException(this.message, {this.denied = false});

  final String message;

  /// Pengguna menolak (atau sebelumnya memblokir) izin notifikasi.
  final bool denied;

  @override
  String toString() => message;
}
