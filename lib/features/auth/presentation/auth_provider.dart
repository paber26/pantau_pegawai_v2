import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/network_providers.dart';
import '../../../core/services/push/push_service_provider.dart';
import '../data/auth_repository.dart';
import '../data/auth_repository_impl.dart';
import '../domain/auth_state.dart';

part 'auth_provider.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  );
}

@riverpod
Stream<AppAuthUser?> authState(Ref ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
}

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(
            email: email,
            password: password,
          ),
    );
  }

  Future<void> logout() async {
    // Perangkat ini berhenti menerima pengingat akun ini. Langganan di server
    // ikut terhapus bersama sesinya.
    try {
      await ref.read(pushServiceProvider).unsubscribe();
    } catch (_) {}
    await ref.read(authRepositoryProvider).logout();
  }
}
