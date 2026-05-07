import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';

class ProjectPickerSheet extends ConsumerWidget {
  final int? currentProjectId;
  final void Function(int?) onSelected;

  const ProjectPickerSheet({
    super.key,
    required this.currentProjectId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projectsAsync = ref.watch(projectsControllerProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l10n.selectProject,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            // "All Tasks" always visible
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(l10n.allTasks),
              trailing: currentProjectId == null
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              selected: currentProjectId == null,
              onTap: () {
                Navigator.pop(context);
                onSelected(null);
              },
            ),
            const Divider(height: 1),
            // Projects list
            Expanded(
              child: projectsAsync.when(
                data: (model) => ListView(
                  controller: scrollController,
                  children: model.projects
                      .expand((p) => _flattenProject(context, p, depth: 0))
                      .toList(),
                ),
                loading: () => const Center(child: LoadingWidget()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: VikunjaErrorWidget(error: err),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _flattenProject(
    BuildContext context,
    Project project, {
    required int depth,
  }) {
    return [
      _buildProjectItem(context, project, depth: depth),
      ...project.subprojects.expand(
        (sub) => _flattenProject(context, sub, depth: depth + 1),
      ),
    ];
  }

  Widget _buildProjectItem(
    BuildContext context,
    Project project, {
    required int depth,
  }) {
    final isSelected = project.id == currentProjectId;

    return ListTile(
      contentPadding: EdgeInsets.only(left: 16 + (depth * 16.0), right: 16),
      leading: Icon(
        project.id < 0 ? Icons.filter_alt_outlined : Icons.folder_outlined,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(project.title, overflow: TextOverflow.ellipsis),
      trailing: isSelected
          ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
          : null,
      selected: isSelected,
      onTap: () {
        Navigator.pop(context);
        onSelected(project.id);
      },
    );
  }
}
