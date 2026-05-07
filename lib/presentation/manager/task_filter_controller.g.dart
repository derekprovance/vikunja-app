// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_filter_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskFilterController)
final taskFilterControllerProvider = TaskFilterControllerFamily._();

final class TaskFilterControllerProvider
    extends $AsyncNotifierProvider<TaskFilterController, TaskFilter> {
  TaskFilterControllerProvider._({
    required TaskFilterControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'taskFilterControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskFilterControllerHash();

  @override
  String toString() {
    return r'taskFilterControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskFilterController create() => TaskFilterController();

  @override
  bool operator ==(Object other) {
    return other is TaskFilterControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskFilterControllerHash() =>
    r'5a5c92e17c9171a4fae3722103af00e92a3b8b5c';

final class TaskFilterControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskFilterController,
          AsyncValue<TaskFilter>,
          TaskFilter,
          FutureOr<TaskFilter>,
          String
        > {
  TaskFilterControllerFamily._()
    : super(
        retry: null,
        name: r'taskFilterControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TaskFilterControllerProvider call(String pageKey) =>
      TaskFilterControllerProvider._(argument: pageKey, from: this);

  @override
  String toString() => r'taskFilterControllerProvider';
}

abstract class _$TaskFilterController extends $AsyncNotifier<TaskFilter> {
  late final _$args = ref.$arg as String;
  String get pageKey => _$args;

  FutureOr<TaskFilter> build(String pageKey);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TaskFilter>, TaskFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TaskFilter>, TaskFilter>,
              AsyncValue<TaskFilter>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
