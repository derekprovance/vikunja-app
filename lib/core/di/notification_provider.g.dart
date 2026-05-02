// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Notification)
final notificationProvider = NotificationProvider._();

final class NotificationProvider
    extends $NotifierProvider<Notification, NotificationHandler?> {
  NotificationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationHash();

  @$internal
  @override
  Notification create() => Notification();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationHandler? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationHandler?>(value),
    );
  }
}

String _$notificationHash() => r'c1522e6a834ddc454d0445cb95470f2214804684';

abstract class _$Notification extends $Notifier<NotificationHandler?> {
  NotificationHandler? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<NotificationHandler?, NotificationHandler?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NotificationHandler?, NotificationHandler?>,
              NotificationHandler?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
