// Implementasi web: memanggil `window.pawaiPush` dari web/pawai_push.js.
// Hanya dimuat di web (lihat import bersyarat di push_service_provider.dart).

import 'dart:convert';
import 'dart:js_interop';

import 'push_service.dart';

@JS('pawaiPush')
external _PawaiPush? get _pawaiPush;

/// Semua fungsi mengembalikan Promise berisi string JSON dan tidak reject.
extension type _PawaiPush._(JSObject _) implements JSObject {
  external JSPromise<JSString> info();
  external JSPromise<JSString> subscribe(String publicKey);
  external JSPromise<JSString> unsubscribe();
}

class WebPushService implements PushService {
  Future<Map<String, dynamic>?> _call(
      JSPromise<JSString> Function(_PawaiPush api) fn) async {
    final api = _pawaiPush;
    if (api == null) return null;
    final json = (await fn(api).toDart).toDart;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  @override
  Future<PushDeviceInfo> info() async {
    final json = await _call((api) => api.info());
    return json == null
        ? PushDeviceInfo.unsupported
        : PushDeviceInfo.fromJson(json);
  }

  @override
  Future<PushSubscriptionData> subscribe(String publicKey) async {
    final json = await _call((api) => api.subscribe(publicKey));
    final error = json == null ? 'unsupported' : json['error'] as String?;
    if (error == 'denied') {
      throw const PushException('Izin notifikasi ditolak.', denied: true);
    }
    if (error == 'unsupported') {
      throw const PushException('Perangkat ini tidak mendukung notifikasi.');
    }
    if (error != null) throw PushException('Gagal mengaktifkan: $error');
    return PushSubscriptionData.fromJson(
        json!['subscription'] as Map<String, dynamic>);
  }

  @override
  Future<String?> unsubscribe() async {
    final json = await _call((api) => api.unsubscribe());
    final error = json?['error'] as String?;
    if (error != null) throw PushException('Gagal mematikan: $error');
    return json?['endpoint'] as String?;
  }
}
