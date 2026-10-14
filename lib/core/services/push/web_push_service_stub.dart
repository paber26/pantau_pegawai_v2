// Pengganti untuk platform non-web (APK/iOS native): notifikasi web tidak
// tersedia.

import 'push_service.dart';

class WebPushService implements PushService {
  @override
  Future<PushDeviceInfo> info() async => PushDeviceInfo.unsupported;

  @override
  Future<PushSubscriptionData> subscribe(String publicKey) =>
      throw const PushException('Perangkat ini tidak mendukung notifikasi.');

  @override
  Future<String?> unsubscribe() async => null;
}
