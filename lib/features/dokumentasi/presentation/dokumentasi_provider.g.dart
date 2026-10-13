// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dokumentasi_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$dokumentasiRepositoryHash() =>
    r'b117954665d53b805ce4ee6ecf544fc581790580';

/// See also [dokumentasiRepository].
@ProviderFor(dokumentasiRepository)
final dokumentasiRepositoryProvider =
    AutoDisposeProvider<DokumentasiRepository>.internal(
  dokumentasiRepository,
  name: r'dokumentasiRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dokumentasiRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DokumentasiRepositoryRef
    = AutoDisposeProviderRef<DokumentasiRepository>;
String _$myDokumentasiNotifierHash() =>
    r'2f1012b6137edf967e1adb20cc0a6058a20ddb44';

/// Dokumentasi milik pegawai yang login
///
/// Copied from [MyDokumentasiNotifier].
@ProviderFor(MyDokumentasiNotifier)
final myDokumentasiNotifierProvider = AutoDisposeAsyncNotifierProvider<
    MyDokumentasiNotifier, List<DokumentasiModel>>.internal(
  MyDokumentasiNotifier.new,
  name: r'myDokumentasiNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myDokumentasiNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$MyDokumentasiNotifier
    = AutoDisposeAsyncNotifier<List<DokumentasiModel>>;
String _$adminDokumentasiNotifierHash() =>
    r'8bb58334461a427b8eb15fdb9a012f29782ab8b1';

/// Semua dokumentasi untuk admin
///
/// Copied from [AdminDokumentasiNotifier].
@ProviderFor(AdminDokumentasiNotifier)
final adminDokumentasiNotifierProvider = AutoDisposeAsyncNotifierProvider<
    AdminDokumentasiNotifier, List<DokumentasiModel>>.internal(
  AdminDokumentasiNotifier.new,
  name: r'adminDokumentasiNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$adminDokumentasiNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AdminDokumentasiNotifier
    = AutoDisposeAsyncNotifier<List<DokumentasiModel>>;
String _$deletedDokumentasiNotifierHash() =>
    r'f3808c7c0ac6ce46d6facf6445d1644c00f3e81b';

/// Dokumentasi yang dihapus pegawai/admin (khusus admin), bisa dikembalikan.
///
/// Copied from [DeletedDokumentasiNotifier].
@ProviderFor(DeletedDokumentasiNotifier)
final deletedDokumentasiNotifierProvider = AutoDisposeAsyncNotifierProvider<
    DeletedDokumentasiNotifier, List<DokumentasiModel>>.internal(
  DeletedDokumentasiNotifier.new,
  name: r'deletedDokumentasiNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deletedDokumentasiNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DeletedDokumentasiNotifier
    = AutoDisposeAsyncNotifier<List<DokumentasiModel>>;
String _$dokumentasiFocusNotifierHash() =>
    r'5f80d1e8cdc26ae5e0e5c7cf0075eb86d05016b7';

/// See also [DokumentasiFocusNotifier].
@ProviderFor(DokumentasiFocusNotifier)
final dokumentasiFocusNotifierProvider = AutoDisposeNotifierProvider<
    DokumentasiFocusNotifier, DokumentasiFocus?>.internal(
  DokumentasiFocusNotifier.new,
  name: r'dokumentasiFocusNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$dokumentasiFocusNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DokumentasiFocusNotifier = AutoDisposeNotifier<DokumentasiFocus?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
