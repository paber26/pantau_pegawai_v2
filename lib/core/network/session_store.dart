import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/auth_state.dart';

/// Menyimpan sesi login (token + profil user) di perangkat dan memberi tahu
/// perubahan status login lewat [watch].
///
/// Token disimpan di `shared_preferences` (localStorage di web), sama seperti
/// sesi Supabase sebelumnya. Profil ikut disimpan supaya aplikasi tetap
/// terbuka dalam keadaan login walau server sedang tidak bisa dihubungi.
class SessionStore {
  static const _tokenKey = 'pantau.session_token';
  static const _userKey = 'pantau.session_user';

  final _changes = StreamController<AppAuthUser?>.broadcast();
  Future<void>? _restoring;
  bool _loaded = false;

  String? _token;
  AppAuthUser? _user;

  String? get token => _token;
  AppAuthUser? get currentUser => _user;

  /// Baca token & profil tersimpan dari perangkat (tanpa akses jaringan).
  /// Dipanggil di `main()` sebelum `runApp`, supaya request pertama setelah
  /// halaman di-refresh sudah membawa token.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final cached = prefs.getString(_userKey);
    if (_token != null && cached != null) {
      _user = AppAuthUser.fromMap(jsonDecode(cached) as Map<String, dynamic>);
    }
    _loaded = true;
  }

  /// Pulihkan sesi tersimpan (sekali saja). [fetchProfile] dipanggil untuk
  /// memastikan token masih berlaku dan mengambil profil terbaru; boleh
  /// melempar error jaringan, dalam hal itu profil yang tersimpan dipakai.
  Future<void> restore(Future<AppAuthUser?> Function() fetchProfile) {
    return _restoring ??= _restore(fetchProfile);
  }

  Future<void> _restore(Future<AppAuthUser?> Function() fetchProfile) async {
    if (!_loaded) await load();
    if (_token == null) return;

    try {
      final fresh = await fetchProfile();
      if (fresh != null && _token != null) await _persistUser(fresh);
    } catch (_) {
      // Token ditolak → sesi sudah dihapus oleh ApiClient.
      // Server tidak bisa dihubungi → tetap pakai profil tersimpan.
    }
  }

  Future<void> save(String token, AppAuthUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _token = token;
    await _persistUser(user);
    _changes.add(user);
  }

  Future<void> clear() async {
    final hadSession = _token != null;
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    if (hadSession) _changes.add(null);
  }

  Future<void> _persistUser(AppAuthUser user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toMap()));
  }

  /// Stream status login: nilai saat ini (setelah sesi dipulihkan), lalu
  /// setiap perubahan (login/logout/sesi kedaluwarsa).
  Stream<AppAuthUser?> watch(Future<AppAuthUser?> Function() fetchProfile) {
    StreamSubscription<AppAuthUser?>? sub;
    late final StreamController<AppAuthUser?> controller;
    controller = StreamController<AppAuthUser?>(
      onListen: () async {
        await restore(fetchProfile);
        if (controller.isClosed) return;
        sub = _changes.stream.listen(controller.add);
        controller.add(_user);
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }
}
