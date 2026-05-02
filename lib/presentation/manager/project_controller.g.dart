// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProjectController)
final projectControllerProvider = ProjectControllerFamily._();

final class ProjectControllerProvider
    extends $AsyncNotifierProvider<ProjectController, ProjectPageModel> {
  ProjectControllerProvider._({
    required ProjectControllerFamily super.from,
    required Project super.argument,
  }) : super(
         retry: null,
         name: r'projectControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectControllerHash();

  @override
  String toString() {
    return r'projectControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProjectController create() => ProjectController();

  @override
  bool operator ==(Object other) {
    return other is ProjectControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectControllerHash() => r'2ae4088dfc5ed100c9509c2b6955c51f6f921ed9';

final class ProjectControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ProjectController,
          AsyncValue<ProjectPageModel>,
          ProjectPageModel,
          FutureOr<ProjectPageModel>,
          Project
        > {
  ProjectControllerFamily._()
    : super(
        retry: null,
        name: r'projectControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProjectControllerProvider call(Project project) =>
      ProjectControllerProvider._(argument: project, from: this);

  @override
  String toString() => r'projectControllerProvider';
}

abstract class _$ProjectController extends $AsyncNotifier<ProjectPageModel> {
  late final _$args = ref.$arg as Project;
  Project get project => _$args;

  FutureOr<ProjectPageModel> build(Project project);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ProjectPageModel>, ProjectPageModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProjectPageModel>, ProjectPageModel>,
              AsyncValue<ProjectPageModel>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
