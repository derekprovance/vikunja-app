// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_section_collapsed_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskSectionCollapsedController)
final taskSectionCollapsedControllerProvider =
    TaskSectionCollapsedControllerProvider._();

final class TaskSectionCollapsedControllerProvider
    extends
        $AsyncNotifierProvider<TaskSectionCollapsedController, Set<String>> {
  TaskSectionCollapsedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskSectionCollapsedControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskSectionCollapsedControllerHash();

  @$internal
  @override
  TaskSectionCollapsedController create() => TaskSectionCollapsedController();
}

String _$taskSectionCollapsedControllerHash() =>
    r'7fa593f45343fb65c32f05aaab1fa643e4a1cec3';

abstract class _$TaskSectionCollapsedController
    extends $AsyncNotifier<Set<String>> {
  FutureOr<Set<String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Set<String>>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Set<String>>, Set<String>>,
              AsyncValue<Set<String>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
