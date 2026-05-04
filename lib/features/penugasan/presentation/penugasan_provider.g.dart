// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'penugasan_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$penugasanRepositoryHash() =>
    r'89ae50e78e167f4e03953747eed6c5bbea024f56';

/// See also [penugasanRepository].
@ProviderFor(penugasanRepository)
final penugasanRepositoryProvider =
    AutoDisposeProvider<PenugasanRepository>.internal(
  penugasanRepository,
  name: r'penugasanRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$penugasanRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PenugasanRepositoryRef = AutoDisposeProviderRef<PenugasanRepository>;
String _$penugasanNotifierHash() => r'58b07958be8840e202fd8559dd2c33fac01170f9';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$PenugasanNotifier
    extends BuildlessAutoDisposeAsyncNotifier<List<PenugasanModel>> {
  late final String kegiatanId;

  FutureOr<List<PenugasanModel>> build(
    String kegiatanId,
  );
}

/// See also [PenugasanNotifier].
@ProviderFor(PenugasanNotifier)
const penugasanNotifierProvider = PenugasanNotifierFamily();

/// See also [PenugasanNotifier].
class PenugasanNotifierFamily extends Family<AsyncValue<List<PenugasanModel>>> {
  /// See also [PenugasanNotifier].
  const PenugasanNotifierFamily();

  /// See also [PenugasanNotifier].
  PenugasanNotifierProvider call(
    String kegiatanId,
  ) {
    return PenugasanNotifierProvider(
      kegiatanId,
    );
  }

  @override
  PenugasanNotifierProvider getProviderOverride(
    covariant PenugasanNotifierProvider provider,
  ) {
    return call(
      provider.kegiatanId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'penugasanNotifierProvider';
}

/// See also [PenugasanNotifier].
class PenugasanNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    PenugasanNotifier, List<PenugasanModel>> {
  /// See also [PenugasanNotifier].
  PenugasanNotifierProvider(
    String kegiatanId,
  ) : this._internal(
          () => PenugasanNotifier()..kegiatanId = kegiatanId,
          from: penugasanNotifierProvider,
          name: r'penugasanNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$penugasanNotifierHash,
          dependencies: PenugasanNotifierFamily._dependencies,
          allTransitiveDependencies:
              PenugasanNotifierFamily._allTransitiveDependencies,
          kegiatanId: kegiatanId,
        );

  PenugasanNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.kegiatanId,
  }) : super.internal();

  final String kegiatanId;

  @override
  FutureOr<List<PenugasanModel>> runNotifierBuild(
    covariant PenugasanNotifier notifier,
  ) {
    return notifier.build(
      kegiatanId,
    );
  }

  @override
  Override overrideWith(PenugasanNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: PenugasanNotifierProvider._internal(
        () => create()..kegiatanId = kegiatanId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        kegiatanId: kegiatanId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<PenugasanNotifier,
      List<PenugasanModel>> createElement() {
    return _PenugasanNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PenugasanNotifierProvider && other.kegiatanId == kegiatanId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, kegiatanId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PenugasanNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<List<PenugasanModel>> {
  /// The parameter `kegiatanId` of this provider.
  String get kegiatanId;
}

class _PenugasanNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<PenugasanNotifier,
        List<PenugasanModel>> with PenugasanNotifierRef {
  _PenugasanNotifierProviderElement(super.provider);

  @override
  String get kegiatanId => (origin as PenugasanNotifierProvider).kegiatanId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
