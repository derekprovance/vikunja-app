// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Theme)
final themeProvider = ThemeProvider._();

final class ThemeProvider extends $AsyncNotifierProvider<Theme, ThemeModel> {
  ThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeHash();

  @$internal
  @override
  Theme create() => Theme();
}

String _$themeHash() => r'4afd332806d17d863d85d016261953b80dbd28fe';

abstract class _$Theme extends $AsyncNotifier<ThemeModel> {
  FutureOr<ThemeModel> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ThemeModel>, ThemeModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ThemeModel>, ThemeModel>,
              AsyncValue<ThemeModel>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
