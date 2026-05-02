// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides an optional locale override. When null, system locale is used.

@ProviderFor(LocaleOverride)
final localeOverrideProvider = LocaleOverrideProvider._();

/// Provides an optional locale override. When null, system locale is used.
final class LocaleOverrideProvider
    extends $AsyncNotifierProvider<LocaleOverride, Locale?> {
  /// Provides an optional locale override. When null, system locale is used.
  LocaleOverrideProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeOverrideProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeOverrideHash();

  @$internal
  @override
  LocaleOverride create() => LocaleOverride();
}

String _$localeOverrideHash() => r'0fddcfb0e4fa1e3f927a35352debac29865f1036';

/// Provides an optional locale override. When null, system locale is used.

abstract class _$LocaleOverride extends $AsyncNotifier<Locale?> {
  FutureOr<Locale?> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Locale?>, Locale?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Locale?>, Locale?>,
              AsyncValue<Locale?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
