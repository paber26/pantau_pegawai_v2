// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'laporan_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$laporanRepositoryHash() => r'024ba8d612082b2466732132818486fab07060c2';

/// See also [laporanRepository].
@ProviderFor(laporanRepository)
final laporanRepositoryProvider =
    AutoDisposeProvider<LaporanRepository>.internal(
  laporanRepository,
  name: r'laporanRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$laporanRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LaporanRepositoryRef = AutoDisposeProviderRef<LaporanRepository>;
String _$myLaporanHash() => r'5cb11eba23f88f8d4eb672a5ddd9b9bd6aa65a4c';

/// Laporan milik pegawai yang sedang login
///
/// Copied from [myLaporan].
@ProviderFor(myLaporan)
final myLaporanProvider =
    AutoDisposeFutureProvider<List<LaporanModel>>.internal(
  myLaporan,
  name: r'myLaporanProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$myLaporanHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyLaporanRef = AutoDisposeFutureProviderRef<List<LaporanModel>>;
String _$adminLaporanNotifierHash() =>
    r'c2b1c45537d9611aef59646a69576267162fe9b8';

/// Semua laporan (admin) dengan filter opsional
///
/// Copied from [AdminLaporanNotifier].
@ProviderFor(AdminLaporanNotifier)
final adminLaporanNotifierProvider = AutoDisposeAsyncNotifierProvider<
    AdminLaporanNotifier, List<LaporanModel>>.internal(
  AdminLaporanNotifier.new,
  name: r'adminLaporanNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$adminLaporanNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AdminLaporanNotifier = AutoDisposeAsyncNotifier<List<LaporanModel>>;
String _$uploadLaporanNotifierHash() =>
    r'1ea26707b271e599624afc4778fb0860786cf4ae';

/// Upload laporan baru
///
/// Copied from [UploadLaporanNotifier].
@ProviderFor(UploadLaporanNotifier)
final uploadLaporanNotifierProvider = AutoDisposeNotifierProvider<
    UploadLaporanNotifier, AsyncValue<void>>.internal(
  UploadLaporanNotifier.new,
  name: r'uploadLaporanNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$uploadLaporanNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$UploadLaporanNotifier = AutoDisposeNotifier<AsyncValue<void>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
