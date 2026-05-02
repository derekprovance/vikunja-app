// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_comments_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskCommentsController)
final taskCommentsControllerProvider = TaskCommentsControllerFamily._();

final class TaskCommentsControllerProvider
    extends $AsyncNotifierProvider<TaskCommentsController, List<TaskComment>> {
  TaskCommentsControllerProvider._({
    required TaskCommentsControllerFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'taskCommentsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskCommentsControllerHash();

  @override
  String toString() {
    return r'taskCommentsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskCommentsController create() => TaskCommentsController();

  @override
  bool operator ==(Object other) {
    return other is TaskCommentsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskCommentsControllerHash() =>
    r'e5127e8da1ffb404a33031d1026ce9626a7047e6';

final class TaskCommentsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskCommentsController,
          AsyncValue<List<TaskComment>>,
          List<TaskComment>,
          FutureOr<List<TaskComment>>,
          int
        > {
  TaskCommentsControllerFamily._()
    : super(
        retry: null,
        name: r'taskCommentsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TaskCommentsControllerProvider call(int taskId) =>
      TaskCommentsControllerProvider._(argument: taskId, from: this);

  @override
  String toString() => r'taskCommentsControllerProvider';
}

abstract class _$TaskCommentsController
    extends $AsyncNotifier<List<TaskComment>> {
  late final _$args = ref.$arg as int;
  int get taskId => _$args;

  FutureOr<List<TaskComment>> build(int taskId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<TaskComment>>, List<TaskComment>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<TaskComment>>, List<TaskComment>>,
              AsyncValue<List<TaskComment>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
