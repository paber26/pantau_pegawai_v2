import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'push_service.dart';
// Web: memanggil web/pawai_push.js. Platform lain: stub (tidak didukung).
import 'web_push_service.dart'
    if (dart.library.io) 'web_push_service_stub.dart';

part 'push_service_provider.g.dart';

@Riverpod(keepAlive: true)
PushService pushService(Ref ref) => WebPushService();
