import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/core/services/push/push_service.dart';
import 'package:pantau_pegawai/core/services/push/push_service_provider.dart';
import 'package:pantau_pegawai/features/auth/data/auth_repository.dart';
import 'package:pantau_pegawai/features/auth/domain/auth_state.dart';
import 'package:pantau_pegawai/features/auth/presentation/auth_provider.dart';
import 'package:pantau_pegawai/features/pengingat/data/pengingat_repository.dart';
import 'package:pantau_pegawai/features/pengingat/presentation/pengingat_provider.dart';
import 'package:pantau_pegawai/features/pengingat/presentation/pengingat_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sub = PushSubscriptionData(
    endpoint: 'https://fcm.googleapis.com/fcm/send/hp', p256dh: 'p', auth: 'a');

class _FakePush implements PushService {
  _FakePush(this.device);

  PushDeviceInfo device;
  PushException? subscribeError;
  final subscribedWith = <String>[];
  var unsubscribed = 0;

  @override
  Future<PushDeviceInfo> info() async => device;

  @override
  Future<PushSubscriptionData> subscribe(String publicKey) async {
    subscribedWith.add(publicKey);
    if (subscribeError != null) throw subscribeError!;
    return _sub;
  }

  @override
  Future<String?> unsubscribe() async {
    unsubscribed++;
    return _sub.endpoint;
  }
}

class _FakeRepo implements PengingatRepository {
  _FakeRepo({this.enabled = true});

  final bool enabled;
  var configCalls = 0;
  final subscribed = <String>[];
  final unsubscribed = <String>[];
  var tests = 0;

  @override
  Future<PengingatConfig> getConfig() async {
    configCalls++;
    return PengingatConfig(
      enabled: enabled,
      publicKey: enabled ? 'KUNCI' : null,
      reminderTime: '15:00',
      daysLabel: 'Senin–Jumat',
    );
  }

  @override
  Future<void> subscribe(PushSubscriptionData subscription) async =>
      subscribed.add(subscription.endpoint);

  @override
  Future<void> unsubscribe(String endpoint) async => unsubscribed.add(endpoint);

  @override
  Future<void> sendTest() async => tests++;
}

PushDeviceInfo _device({
  bool supported = true,
  bool ios = false,
  bool standalone = false,
  String permission = 'default',
  PushSubscriptionData? subscription,
  String? serverKey,
}) =>
    PushDeviceInfo(
      supported: supported,
      ios: ios,
      standalone: standalone,
      permission: permission,
      subscription: subscription,
      serverKey: serverKey,
    );

ProviderContainer _container(_FakePush push, _FakeRepo repo) {
  final c = ProviderContainer(overrides: [
    pushServiceProvider.overrideWithValue(push),
    pengingatRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<PengingatState> _state(ProviderContainer c) =>
    c.read(pengingatNotifierProvider.future);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('status', () {
    test('APK / browser tanpa Push API → tidak didukung, server tidak dihubungi',
        () async {
      final repo = _FakeRepo();
      final c = _container(_FakePush(PushDeviceInfo.unsupported), repo);
      expect((await _state(c)).status, PengingatStatus.unsupported);
      expect(repo.configCalls, 0);
    });

    test('iPhone di tab browser → perlu dipasang di layar utama', () async {
      final c = _container(
          _FakePush(_device(supported: false, ios: true)), _FakeRepo());
      expect((await _state(c)).status, PengingatStatus.needsInstall);
    });

    test('server belum diisi kunci → serverDisabled', () async {
      final c = _container(_FakePush(_device()), _FakeRepo(enabled: false));
      expect((await _state(c)).status, PengingatStatus.serverDisabled);
    });

    test('izin diblokir → denied', () async {
      final c =
          _container(_FakePush(_device(permission: 'denied')), _FakeRepo());
      expect((await _state(c)).status, PengingatStatus.denied);
    });

    test('sudah berlangganan dengan kunci yang sama → aktif, disinkronkan',
        () async {
      final repo = _FakeRepo();
      final c = _container(
          _FakePush(_device(
              permission: 'granted', subscription: _sub, serverKey: 'KUNCI')),
          repo);
      final s = await _state(c);
      expect(s.status, PengingatStatus.on);
      expect(s.jadwal, 'Senin–Jumat pukul 15.00');
      expect(repo.subscribed, [_sub.endpoint]);
    });

    test('langganan dengan kunci server lama → perlu diaktifkan ulang',
        () async {
      final c = _container(
          _FakePush(_device(
              permission: 'granted', subscription: _sub, serverKey: 'LAMA')),
          _FakeRepo());
      expect((await _state(c)).status, PengingatStatus.off);
    });
  });

  group('aksi', () {
    test('aktifkan: berlangganan dengan kunci server lalu daftar ke server',
        () async {
      final push = _FakePush(_device());
      final repo = _FakeRepo();
      final c = _container(push, repo);
      await _state(c);

      final error = await c.read(pengingatNotifierProvider.notifier).aktifkan();

      expect(error, isNull);
      expect(push.subscribedWith, ['KUNCI']);
      expect(repo.subscribed, [_sub.endpoint]);
      expect((await _state(c)).status, PengingatStatus.on);
    });

    test('aktifkan ditolak pengguna → denied dengan pesan', () async {
      final push = _FakePush(_device())
        ..subscribeError =
            const PushException('Izin notifikasi ditolak.', denied: true);
      final repo = _FakeRepo();
      final c = _container(push, repo);
      await _state(c);

      final error = await c.read(pengingatNotifierProvider.notifier).aktifkan();

      expect(error, 'Izin notifikasi ditolak.');
      expect(repo.subscribed, isEmpty);
      expect((await _state(c)).status, PengingatStatus.denied);
    });

    test('matikan: berhenti berlangganan lalu hapus di server', () async {
      final push = _FakePush(_device(
          permission: 'granted', subscription: _sub, serverKey: 'KUNCI'));
      final repo = _FakeRepo();
      final c = _container(push, repo);
      await _state(c);

      expect(await c.read(pengingatNotifierProvider.notifier).matikan(), isNull);

      expect(push.unsubscribed, 1);
      expect(repo.unsubscribed, [_sub.endpoint]);
      expect((await _state(c)).status, PengingatStatus.off);
    });

    test('logout juga berhenti berlangganan di perangkat ini', () async {
      final push = _FakePush(_device());
      final auth = _FakeAuthRepository();
      final c = ProviderContainer(overrides: [
        pushServiceProvider.overrideWithValue(push),
        authRepositoryProvider.overrideWithValue(auth),
      ]);
      addTearDown(c.dispose);

      await c.read(authNotifierProvider.notifier).logout();

      expect(push.unsubscribed, 1);
      expect(auth.loggedOut, isTrue);
    });
  });

  group('tampilan', () {
    Future<(_FakePush, _FakeRepo)> pump(WidgetTester tester, Widget child,
        {PushDeviceInfo? device}) async {
      final push = _FakePush(device ?? _device());
      final repo = _FakeRepo();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          pushServiceProvider.overrideWithValue(push),
          pengingatRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: child))),
      ));
      await tester.pumpAndSettle();
      return (push, repo);
    }

    testWidgets('Profil: aktifkan lewat switch, lalu kirim notifikasi uji',
        (tester) async {
      final (push, repo) = await pump(tester, const PengingatTile());
      expect(find.textContaining('Ingatkan saya Senin–Jumat pukul 15.00'),
          findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(push.subscribedWith, ['KUNCI']);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('Pengingat harian aktif'), findsOneWidget);

      await tester.tap(find.text('Kirim notifikasi uji'));
      await tester.pumpAndSettle();
      expect(repo.tests, 1);
      expect(find.textContaining('Notifikasi uji dikirim'), findsOneWidget);
    });

    testWidgets('Profil di iPhone (tab browser): petunjuk pasang, tanpa switch',
        (tester) async {
      await pump(tester, const PengingatTile(),
          device: _device(supported: false, ios: true));
      expect(find.textContaining('Tambah ke Layar Utama'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('Banner: "Nanti" menutup dan diingat', (tester) async {
      await pump(tester, const PengingatBanner());
      expect(find.textContaining('Aktifkan pengingat harian?'), findsOneWidget);

      await tester.tap(find.text('Nanti'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Aktifkan pengingat harian?'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PengingatNotifier.bannerKey), isTrue);
    });

    testWidgets('Banner: "Aktifkan" mengaktifkan lalu hilang', (tester) async {
      final (push, repo) = await pump(tester, const PengingatBanner());

      await tester.tap(find.text('Aktifkan'));
      await tester.pumpAndSettle();

      expect(repo.subscribed, [_sub.endpoint]);
      expect(find.textContaining('Aktifkan pengingat harian?'), findsNothing);
      expect(find.text('Pengingat harian aktif'), findsOneWidget); // snackbar
    });

    testWidgets('Banner tidak tampil bila pernah ditutup', (tester) async {
      SharedPreferences.setMockInitialValues(
          {PengingatNotifier.bannerKey: true});
      await pump(tester, const PengingatBanner());
      expect(find.textContaining('pengingat harian'), findsNothing);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  bool loggedOut = false;

  @override
  Future<void> logout() async => loggedOut = true;

  @override
  Future<AppAuthUser> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AppAuthUser?> getCurrentUser() async => null;

  @override
  Stream<AppAuthUser?> authStateChanges() => const Stream.empty();

  @override
  Future<void> changePassword(
          {required String currentPassword, required String newPassword}) =>
      throw UnimplementedError();
}
