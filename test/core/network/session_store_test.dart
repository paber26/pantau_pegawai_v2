import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/core/errors/app_exception.dart';
import 'package:pantau_pegawai/core/network/session_store.dart';
import 'package:pantau_pegawai/features/auth/domain/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cached = AppAuthUser(
  id: 'u1',
  nama: 'Nama Lama',
  email: 'budi@bps.go.id',
  role: 'pegawai',
);

void main() {
  test('tanpa sesi tersimpan → emit null tanpa memanggil server', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    final store = SessionStore();

    final first = await store.watch(() async {
      calls++;
      return null;
    }).first;

    expect(first, isNull);
    expect(calls, 0);
  });

  test('sesi tersimpan dipulihkan dengan profil terbaru dari server', () async {
    SharedPreferences.setMockInitialValues({
      'pantau.session_token': 'tok',
      'pantau.session_user': jsonEncode(_cached.toMap()),
    });
    final store = SessionStore();

    final first = await store
        .watch(() async => const AppAuthUser(
              id: 'u1',
              nama: 'Nama Baru',
              email: 'budi@bps.go.id',
              role: 'admin',
            ))
        .first;

    expect(first?.nama, 'Nama Baru');
    expect(first?.isAdmin, isTrue);
    expect(store.token, 'tok');
  });

  test('load() memuat token tanpa akses jaringan (dipakai sebelum runApp)',
      () async {
    SharedPreferences.setMockInitialValues({
      'pantau.session_token': 'tok',
      'pantau.session_user': jsonEncode(_cached.toMap()),
    });
    final store = SessionStore();
    await store.load();

    expect(store.token, 'tok');
    expect(store.currentUser?.nama, 'Nama Lama');
  });

  test('server tidak bisa dihubungi → tetap login dengan profil tersimpan',
      () async {
    SharedPreferences.setMockInitialValues({
      'pantau.session_token': 'tok',
      'pantau.session_user': jsonEncode(_cached.toMap()),
    });
    final store = SessionStore();

    final first = await store
        .watch(() async =>
            throw const AppException('offline', code: 'network_error'))
        .first;

    expect(first?.nama, 'Nama Lama');
  });

  test('watch: nilai awal lalu perubahan login/logout', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SessionStore();
    final events = <String?>[];
    final sub =
        store.watch(() async => null).listen((u) => events.add(u?.nama));
    await Future<void>.delayed(Duration.zero);

    await store.save('tok', _cached);
    await store.clear();
    await Future<void>.delayed(Duration.zero);

    expect(events, [null, 'Nama Lama', null]);
    await sub.cancel();
  });
}
