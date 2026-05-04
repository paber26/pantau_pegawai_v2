import '../domain/auth_state.dart';

abstract class AuthRepository {
  Future<AppAuthUser> login({required String email, required String password});
  Future<void> logout();
  Future<AppAuthUser?> getCurrentUser();
  Stream<AppAuthUser?> authStateChanges();
}
