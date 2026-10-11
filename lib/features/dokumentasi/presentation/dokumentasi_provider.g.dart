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
    r'370496bd1ad9f4d7654b4d8984466ab16fa3f863';

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
    r'11c733d315db2897866102b7d47f5f1387104d42';

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
    r'702590f191b0d5b77f51dd79599d12f854dfca16';

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
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
