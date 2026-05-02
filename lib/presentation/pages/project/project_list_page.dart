import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/theming/app_colors.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/project/expansion_title.dart';
import 'package:vikunja_app/presentation/pages/project/project_detail_page.dart';
import 'package:vikunja_app/presentation/widgets/project/add_project_dialog.dart';

class ProjectListPage extends ConsumerWidget {
  const ProjectListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(projectsControllerProvider);

    return controller.when(
      data: (model) {
        final projects = model.projects;
        final itemCount = projects.length + (model.isLoadingNextPage ? 1 : 0);
        return Scaffold(
          body: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo.metrics.pixels ==
                  scrollInfo.metrics.maxScrollExtent) {
                ref.read(projectsControllerProvider.notifier).loadNextPage();
              }
              return false;
            },
            child: RefreshIndicator(
              child: ListView.separated(
                itemCount: itemCount,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  if (index == projects.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Center(
                        child: SpinKitThreeBounce(
                          color: Theme.of(context).primaryColor,
                          size: 16,
                        ),
                      ),
                    );
                  }
                  return _buildListItem(context, ref, projects[index]);
                },
              ),
              onRefresh: () async {
                ref.read(projectsControllerProvider.notifier).reload();
              },
            ),
          ),
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).projectsTitle),
            actions: [
              IconButton(
                icon: Icon(Icons.add),
                onPressed: () => _addProjectDialog(ref),
              ),
            ],
          ),
        );
      },
      error: (err, _) => VikunjaErrorWidget(
        error: err,
        onRetry: () => ref.invalidate(projectsControllerProvider),
      ),
      loading: () => const LoadingWidget(),
    );
  }

  Widget _buildListItem(BuildContext context, WidgetRef ref, Project project) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>();
    final starColor = appColors?.success ?? colorScheme.tertiary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (project.subprojects.isEmpty)
            ListTile(
              leading: _buildLeadingIcon(project),
              title: Text(project.title),
              subtitle: project.description.isNotEmpty
                  ? Text(
                      project.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    )
                  : null,
              trailing: project.isFavourite
                  ? Icon(Icons.star_rounded,
                      size: 18, color: starColor)
                  : null,
              onTap: () => _navigateToProject(ref, project),
            )
          else
            VikunjaExpansionTile(
              leading: _buildLeadingIcon(project),
              title: _buildExpandedTitle(context, project, starColor),
              children: project.subprojects
                  .map((e) => _buildListItem(context, ref, e))
                  .toList(),
              onTitleTap: () => _navigateToProject(ref, project),
            ),
          if (project.color != null)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 4,
              child: IgnorePointer(
                child: ColoredBox(color: project.color!),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(Project project) {
    if (project.views.isNotEmpty) {
      return project.views.first.icon;
    }
    return const Icon(Icons.folder_outlined);
  }

  Widget _buildExpandedTitle(
      BuildContext context, Project project, Color starColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Text(project.title)),
        if (project.isFavourite)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.star_rounded, size: 16, color: starColor),
          ),
        ...project.views.take(3).map((v) {
          final iconData = v.icon.icon;
          return Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(iconData, size: 14, color: colorScheme.onSurfaceVariant),
          );
        }),
      ],
    );
  }

  void _addProjectDialog(WidgetRef ref) {
    showDialog(
      context: ref.context,
      builder: (_) => AddProjectDialog(onAdd: (name) => _addProject(name, ref)),
    );
  }

  Future<void> _addProject(String name, WidgetRef ref) async {
    final currentUser = ref.read(currentUserProvider);

    ref
        .read(projectsControllerProvider.notifier)
        .create(Project(title: name, owner: currentUser));
  }

  void _navigateToProject(WidgetRef ref, Project project) async {
    Navigator.push(
      ref.context,
      MaterialPageRoute(
        builder: (context) {
          return ProjectDetailPage(
            key: Key(project.id.toString()),
            project: project,
          );
        },
      ),
    );
  }
}
