// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AuthData)
final authDataProvider = AuthDataProvider._();

final class AuthDataProvider extends $NotifierProvider<AuthData, AuthModel?> {
  AuthDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authDataProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authDataHash();

  @$internal
  @override
  AuthData create() => AuthData();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthModel? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthModel?>(value),
    );
  }
}

String _$authDataHash() => r'321e34c6d952287a0371852203f99572aa89a741';

abstract class _$AuthData extends $Notifier<AuthModel?> {
  AuthModel? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AuthModel?, AuthModel?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthModel?, AuthModel?>,
              AuthModel?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(CurrentUser)
final currentUserProvider = CurrentUserProvider._();

final class CurrentUserProvider extends $NotifierProvider<CurrentUser, User?> {
  CurrentUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  CurrentUser create() => CurrentUser();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(User? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<User?>(value),
    );
  }
}

String _$currentUserHash() => r'6c693923886cc2ac9303d1f1c51786f9b4638b0a';

abstract class _$CurrentUser extends $Notifier<User?> {
  User? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<User?, User?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<User?, User?>,
              User?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

@ProviderFor(ClientProvider)
final clientProviderProvider = ClientProviderProvider._();

final class ClientProviderProvider
    extends $NotifierProvider<ClientProvider, Client> {
  ClientProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clientProviderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clientProviderHash();

  @$internal
  @override
  ClientProvider create() => ClientProvider();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Client value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Client>(value),
    );
  }
}

String _$clientProviderHash() => r'd2967557c07a22b8a536b53ac5f4b9152bb05c71';

abstract class _$ClientProvider extends $Notifier<Client> {
  Client build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Client, Client>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Client, Client>,
              Client,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
