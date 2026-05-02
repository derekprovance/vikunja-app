// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'projects_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProjectsController)
final projectsControllerProvider = ProjectsControllerProvider._();

final class ProjectsControllerProvider
    extends $AsyncNotifierProvider<ProjectsController, ProjectListModel> {
  ProjectsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectsControllerHash();

  @$internal
  @override
  ProjectsController create() => ProjectsController();
}

String _$projectsControllerHash() =>
    r'c3a97fd05fa74222afb8b8676e71c7e9d0abd604';

abstract class _$ProjectsController extends $AsyncNotifier<ProjectListModel> {
  FutureOr<ProjectListModel> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ProjectListModel>, ProjectListModel>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProjectListModel>, ProjectListModel>,
              AsyncValue<ProjectListModel>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
