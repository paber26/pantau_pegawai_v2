// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pegawai_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pegawaiRepositoryHash() => r'f6230f706905265be0257fd8cb504c7b25557ad0';

/// See also [pegawaiRepository].
@ProviderFor(pegawaiRepository)
final pegawaiRepositoryProvider =
    AutoDisposeProvider<PegawaiRepository>.internal(
  pegawaiRepository,
  name: r'pegawaiRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pegawaiRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PegawaiRepositoryRef = AutoDisposeProviderRef<PegawaiRepository>;
String _$pegawaiNotifierHash() => r'4d6ad3496f79e9638d437c57045b04b4641c52a5';

/// See also [PegawaiNotifier].
@ProviderFor(PegawaiNotifier)
final pegawaiNotifierProvider = AutoDisposeAsyncNotifierProvider<
    PegawaiNotifier, List<PegawaiModel>>.internal(
  PegawaiNotifier.new,
  name: r'pegawaiNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pegawaiNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$PegawaiNotifier = AutoDisposeAsyncNotifier<List<PegawaiModel>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
