import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session_store.dart';
import '../domain/auth_state.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;
  final SessionStore _session;

  AuthRepositoryImpl(this._api, this._session);

  @override
  Future<AppAuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final data = await _api.post(
        '/api/auth/login',
        body: {'email': email, 'password': password},
      ) as Map<String, dynamic>;

      final user = AppAuthUser.fromMap(data['user'] as Map<String, dynamic>);
      await _session.save(data['token'] as String, user);
      return user;
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('Terjadi kesalahan: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('/api/auth/logout');
    } catch (_) {
      // Tetap keluar walau server tidak bisa dihubungi.
    }
    await _session.clear();
  }

  @override
  Future<AppAuthUser?> getCurrentUser() async {
    await _session.restore(_fetchProfile);
    return _session.currentUser;
  }

  @override
  Stream<AppAuthUser?> authStateChanges() => _session.watch(_fetchProfile);

  Future<AppAuthUser?> _fetchProfile() async {
    final data = await _api.get('/api/auth/me') as Map<String, dynamic>;
    return AppAuthUser.fromMap(data['user'] as Map<String, dynamic>);
  }
}
