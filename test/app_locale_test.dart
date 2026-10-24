import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pantau_pegawai/app.dart';
import 'package:pantau_pegawai/features/auth/presentation/auth_provider.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('aplikasi berbahasa Indonesia: kalender dan tombol bawaan',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [authStateProvider.overrideWith((ref) => Stream.value(null))],
      child: const PantauPegawaiApp(),
    ));
    await tester.pumpAndSettle();

    // Belum login → halaman login; pakai context-nya untuk membuka kalender.
    final context = tester.element(find.byType(Scaffold).first);
    expect(Localizations.localeOf(context), const Locale('id', 'ID'));

    showDatePicker(
      context: context,
      initialDate: DateTime(2026, 7, 20),
      firstDate: DateTime(2026),
      lastDate: DateTime(2026, 12, 31),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juli 2026'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
  });
}
