import '../../../core/network/api_client.dart';
import '../../../core/services/push/push_service.dart';

/// Pengaturan pengingat harian dari server (`GET /api/push/config`).
class PengingatConfig {
  const PengingatConfig({
    required this.enabled,
    required this.publicKey,
    required this.reminderTime,
    required this.daysLabel,
  });

  factory PengingatConfig.fromJson(Map<String, dynamic> json) =>
      PengingatConfig(
        enabled: json['enabled'] == true,
        publicKey: json['public_key'] as String?,
        reminderTime: json['reminder_time'] as String? ?? '15:00',
        daysLabel: json['reminder_days_label'] as String? ?? 'Senin–Jumat',
      );

  /// Server sudah diisi kunci VAPID.
  final bool enabled;
  final String? publicKey;

  /// "HH:MM", zona waktu kantor.
  final String reminderTime;

  /// Mis. "Senin–Jumat".
  final String daysLabel;
}

class PengingatRepository {
  PengingatRepository(this._api);

  final ApiClient _api;

  Future<PengingatConfig> getConfig() async => PengingatConfig.fromJson(
      (await _api.get('/api/push/config')) as Map<String, dynamic>);

  /// Daftarkan langganan perangkat ini ke sesi login sekarang.
  Future<void> subscribe(PushSubscriptionData subscription) =>
      _api.post('/api/push/subscriptions', body: subscription.toJson());

  Future<void> unsubscribe(String endpoint) =>
      _api.post('/api/push/unsubscribe', body: {'endpoint': endpoint});

  /// Kirim notifikasi uji ke perangkat ini.
  Future<void> sendTest() => _api.post('/api/push/test');
}
