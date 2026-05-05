// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'kegiatan_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$kegiatanRepositoryHash() =>
    r'8d7e6ae647fa5b62e28f46c5b5d58158974d4155';

/// See also [kegiatanRepository].
@ProviderFor(kegiatanRepository)
final kegiatanRepositoryProvider =
    AutoDisposeProvider<KegiatanRepository>.internal(
  kegiatanRepository,
  name: r'kegiatanRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$kegiatanRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef KegiatanRepositoryRef = AutoDisposeProviderRef<KegiatanRepository>;
String _$myKegiatanHash() => r'dc3cd0e8594eac5fe03062ffa158976bfbebd3d9';

/// Kegiatan milik pegawai yang sedang login
///
/// Copied from [myKegiatan].
@ProviderFor(myKegiatan)
final myKegiatanProvider =
    AutoDisposeFutureProvider<List<KegiatanModel>>.internal(
  myKegiatan,
  name: r'myKegiatanProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myKegiatanHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyKegiatanRef = AutoDisposeFutureProviderRef<List<KegiatanModel>>;
String _$kegiatanNotifierHash() => r'cc99f9baed7084dc58b3893b7b79a24871044890';

/// Semua kegiatan (untuk admin)
///
/// Copied from [KegiatanNotifier].
@ProviderFor(KegiatanNotifier)
final kegiatanNotifierProvider = AutoDisposeAsyncNotifierProvider<
    KegiatanNotifier, List<KegiatanModel>>.internal(
  KegiatanNotifier.new,
  name: r'kegiatanNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$kegiatanNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$KegiatanNotifier = AutoDisposeAsyncNotifier<List<KegiatanModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
