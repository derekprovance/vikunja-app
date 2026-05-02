// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_page_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskPageController)
final taskPageControllerProvider = TaskPageControllerProvider._();

final class TaskPageControllerProvider
    extends $AsyncNotifierProvider<TaskPageController, TaskPageModel> {
  TaskPageControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskPageControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskPageControllerHash();

  @$internal
  @override
  TaskPageController create() => TaskPageController();
}

String _$taskPageControllerHash() =>
    r'784914dd69f9e0627c0981d5e2a6538a2c236533';

abstract class _$TaskPageController extends $AsyncNotifier<TaskPageModel> {
  FutureOr<TaskPageModel> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<TaskPageModel>, TaskPageModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TaskPageModel>, TaskPageModel>,
              AsyncValue<TaskPageModel>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
