import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantau_pegawai/core/errors/app_exception.dart';
import 'package:pantau_pegawai/features/auth/data/auth_repository.dart';
import 'package:pantau_pegawai/features/auth/domain/auth_state.dart';
import 'package:pantau_pegawai/features/auth/presentation/auth_provider.dart';
import 'package:pantau_pegawai/features/auth/presentation/change_password_dialog.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.error});

  final AppException? error;
  final calls = <(String, String)>[];

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls.add((currentPassword, newPassword));
    if (error != null) throw error!;
  }

  @override
  Future<AppAuthUser> login(
          {required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<AppAuthUser?> getCurrentUser() async => null;

  @override
  Stream<AppAuthUser?> authStateChanges() => const Stream.empty();
}

Future<void> _open(WidgetTester tester, _FakeAuthRepository repo) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showChangePasswordDialog(context),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

Future<void> _isi(
    WidgetTester tester, String lama, String baru, String ulangi) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), lama);
  await tester.enterText(fields.at(1), baru);
  await tester.enterText(fields.at(2), ulangi);
  await tester.tap(find.text('Simpan'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('validasi lokal: kosong, terlalu pendek, ulangi tidak sama',
      (tester) async {
    final repo = _FakeAuthRepository();
    await _open(tester, repo);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Isi password lama.'), findsOneWidget);
    expect(find.text('Isi password baru.'), findsOneWidget);

    await _isi(tester, 'lama123', '123', '123');
    expect(find.text('Minimal 6 karakter.'), findsOneWidget);

    await _isi(tester, 'lama123', 'baru4567', 'beda4567');
    expect(find.text('Password baru tidak sama.'), findsOneWidget);

    expect(repo.calls, isEmpty);
  });

  testWidgets(
      'berhasil: memanggil repository, dialog tertutup, snackbar tampil',
      (tester) async {
    final repo = _FakeAuthRepository();
    await _open(tester, repo);

    await _isi(tester, 'lama123', 'baru4567', 'baru4567');

    expect(repo.calls, [('lama123', 'baru4567')]);
    expect(find.byType(ChangePasswordDialog), findsNothing);
    expect(find.text('Password berhasil diubah'), findsOneWidget);
  });

  testWidgets('error dari server tampil di dialog', (tester) async {
    final repo = _FakeAuthRepository(
        error: const AppException('Password lama salah.', code: '400'));
    await _open(tester, repo);

    await _isi(tester, 'keliru', 'baru4567', 'baru4567');

    expect(find.byType(ChangePasswordDialog), findsOneWidget);
    expect(find.text('Password lama salah.'), findsOneWidget);
  });
}
