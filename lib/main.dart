import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/network/network_providers.dart';
import 'core/network/session_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi locale Indonesia untuk intl
  await initializeDateFormatting('id_ID', null);

  // Muat token login tersimpan sebelum aplikasi tampil, supaya halaman yang
  // dibuka ulang (refresh) langsung bisa memanggil API dengan token.
  final session = SessionStore();
  await session.load();

  runApp(
    ProviderScope(
      overrides: [sessionStoreProvider.overrideWithValue(session)],
      child: const PantauPegawaiApp(),
    ),
  );
}
