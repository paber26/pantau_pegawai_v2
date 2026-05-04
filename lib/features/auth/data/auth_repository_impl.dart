import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../../../core/errors/app_exception.dart';
import '../domain/auth_state.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;

  AuthRepositoryImpl(this._client);

  @override
  Future<AppAuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const AppException('Login gagal. Periksa email dan kata sandi.');
      }

      return await _fetchUserProfile(response.user!.id);
    } on AppException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AppException(e.message);
    } catch (e) {
      throw AppException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  @override
  Future<AppAuthUser?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      return await _fetchUserProfile(user.id);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AppAuthUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((event) async {
      if (event.session == null) return null;
      try {
        return await _fetchUserProfile(event.session!.user.id);
      } catch (_) {
        return null;
      }
    });
  }

  Future<AppAuthUser> _fetchUserProfile(String userId) async {
    final data = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .single();
    return AppAuthUser.fromMap(data);
  }
}
