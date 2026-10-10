import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_client.dart';
import 'session_store.dart';

part 'network_providers.g.dart';

/// Satu instance untuk seluruh aplikasi (keepAlive): menyimpan token login.
@Riverpod(keepAlive: true)
SessionStore sessionStore(Ref ref) => SessionStore();

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) => ApiClient(ref.watch(sessionStoreProvider));
