import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pantau_pegawai/core/errors/app_exception.dart';
import 'package:pantau_pegawai/core/network/api_client.dart';
import 'package:pantau_pegawai/core/network/session_store.dart';
import 'package:pantau_pegawai/features/auth/domain/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _user = AppAuthUser(
  id: 'u1',
  nama: 'Budi Santoso',
  email: 'budi@bps.go.id',
  role: 'pegawai',
);

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  late SessionStore session;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session = SessionStore();
  });

  ApiClient client(MockClientHandler handler) => ApiClient(session,
      httpClient: MockClient(handler), baseUrl: 'https://api.test');

  test('menempelkan token dan membuang query bernilai null', () async {
    await session.save('tok123', _user);
    late http.Request captured;
    final api = client((req) async {
      captured = req;
      return _json([]);
    });

    await api.get('/api/dokumentasi', query: {'user_id': 'u1', 'from': null});

    expect(
        captured.url.toString(), 'https://api.test/api/dokumentasi?user_id=u1');
    expect(captured.headers['Authorization'], 'Bearer tok123');
  });

  test('Content-Type JSON hanya dikirim bila ada body (DELETE/logout tanpa)',
      () async {
    final captured = <http.Request>[];
    final api = client((req) async {
      captured.add(req);
      return _json({'success': true});
    });

    await api.delete('/api/dokumentasi/d1');
    await api.post('/api/auth/logout');
    await api.post('/api/dokumentasi', body: {'proyek': 'X'});

    expect(captured[0].headers.containsKey('content-type'), isFalse);
    expect(captured[1].headers.containsKey('content-type'), isFalse);
    expect(captured[2].headers['content-type'], startsWith('application/json'));
  });

  test('pesan {error} dari server menjadi AppException', () async {
    final api =
        client((_) async => _json({'error': 'Email sudah terdaftar.'}, 409));

    expect(
      () => api.post('/api/users', body: {}),
      throwsA(isA<AppException>()
          .having((e) => e.message, 'message', 'Email sudah terdaftar.')
          .having((e) => e.code, 'code', '409')),
    );
  });

  test('401 saat membawa token → sesi dihapus (kembali ke login)', () async {
    await session.save('kedaluwarsa', _user);
    final events = <AppAuthUser?>[];
    final sub = session.watch(() async => _user).listen(events.add);
    await Future<void>.delayed(Duration.zero);

    final api = client((_) async => _json({'error': 'Sesi tidak valid'}, 401));
    await expectLater(api.get('/api/users'), throwsA(isA<AppException>()));
    await Future<void>.delayed(Duration.zero);

    expect(session.token, isNull);
    expect(events.last, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    await sub.cancel();
  });

  test('401 saat login (tanpa token) tidak dianggap sesi habis', () async {
    final api = client(
        (_) async => _json({'error': 'Email atau kata sandi salah.'}, 401));

    await expectLater(
      api.post('/api/auth/login', body: {}),
      throwsA(isA<AppException>()
          .having((e) => e.message, 'message', 'Email atau kata sandi salah.')),
    );
  });

  test('gagal koneksi → pesan jaringan yang jelas', () async {
    final api =
        client((_) async => throw http.ClientException('Connection refused'));

    expect(
      () => api.get('/api/users'),
      throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'network_error')),
    );
  });

  test('uploadPhoto mengirim multipart tanggal + file dan mengembalikan URL',
      () async {
    await session.save('tok123', _user);
    late http.Request captured;
    final api = client((req) async {
      captured = req;
      return _json({
        'image_url': 'https://api.test/api/images?id=abc',
        'file_id': 'abc'
      });
    });

    final url = await api.uploadPhoto(
      bytes: Uint8List.fromList([1, 2, 3]),
      tanggal: DateTime(2026, 5, 4),
    );

    expect(url, 'https://api.test/api/images?id=abc');
    expect(captured.url.path, '/api/uploads');
    expect(captured.headers['Authorization'], 'Bearer tok123');
    expect(captured.headers['content-type'], startsWith('multipart/form-data'));
    final body = utf8.decode(captured.bodyBytes, allowMalformed: true);
    expect(body, contains('name="tanggal"'));
    expect(body, contains('2026-05-04'));
    expect(body, contains('name="file"'));
  });
}
