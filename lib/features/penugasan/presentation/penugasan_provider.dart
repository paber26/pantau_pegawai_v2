import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/penugasan_repository.dart';
import '../data/penugasan_repository_impl.dart';
import '../domain/penugasan_model.dart';

part 'penugasan_provider.g.dart';

@riverpod
PenugasanRepository penugasanRepository(Ref ref) {
  return PenugasanRepositoryImpl(Supabase.instance.client);
}

@riverpod
class PenugasanNotifier extends _$PenugasanNotifier {
  @override
  Future<List<PenugasanModel>> build(String kegiatanId) async {
    return ref.read(penugasanRepositoryProvider).getByKegiatanId(kegiatanId);
  }

  Future<void> refresh(String kegiatanId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(penugasanRepositoryProvider).getByKegiatanId(kegiatanId),
    );
  }

  Future<bool> assign({
    required String userId,
    required String kegiatanId,
  }) async {
    try {
      await ref.read(penugasanRepositoryProvider).assign(
            userId: userId,
            kegiatanId: kegiatanId,
          );
      await refresh(kegiatanId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unassign({
    required String userId,
    required String kegiatanId,
  }) async {
    try {
      await ref.read(penugasanRepositoryProvider).unassign(
            userId: userId,
            kegiatanId: kegiatanId,
          );
      await refresh(kegiatanId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
