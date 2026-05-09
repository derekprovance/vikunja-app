import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vikunja_app/core/utils/calculate_item_position.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_page_result.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/task/task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task/task_section_header.dart';
import 'package:vikunja_app/presentation/pages/task/task_detail_page.dart';

class ProjectTaskList extends ConsumerWidget {
  final Project project;

  const ProjectTaskList(this.project, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var projectController = ref.watch(projectControllerProvider(project));

    return projectController.when(
      data: (pageModel) {
        List<Widget> children = [];
        if (project.subprojects.isNotEmpty) {
          children.add(
            TaskSectionHeader(
              title: AppLocalizations.of(context).subProjectSection,
              count: project.subprojects.length,
            ),
          );
          children.addAll(_buildProjectList(context));
        }
        if (pageModel.tasks.isNotEmpty) {
          children.add(
            TaskSectionHeader(
              title: AppLocalizations.of(context).tasksSection,
              count: pageModel.tasks.length,
            ),
          );
          children.add(_buildTaskList(ref, pageModel.tasks));
        }

        if (pageModel.isLoadingNextPage) {
          children.add(
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: SpinKitThreeBounce(
                    color: Theme.of(context).primaryColor,
                    size: 16,
                  ),
                ),
              ),
            ),
          );
        }

        if (children.isEmpty) {
          return EmptyView(
            Icons.list,
            AppLocalizations.of(context).noTasksOrSubproject,
          );
        }

        children.add(const SliverToBoxAdapter(child: SizedBox(height: 80)));
        return CustomScrollView(slivers: children);
      },
      error: (err, _) => VikunjaErrorWidget(error: err),
      loading: () => const LoadingWidget(),
    );
  }

  List<Widget> _buildProjectList(BuildContext context) {
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final subproject = project.subprojects.toList()[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                ListTile(
                  leading: subproject.views.isNotEmpty
                      ? subproject.views.first.icon
                      : const Icon(Icons.folder_outlined),
                  title: Text(
                    subproject.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _navigateToDetail(context, subproject),
                ),
                if (subproject.effectiveColor != null)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 0,
                    width: 4,
                    child: IgnorePointer(
                      child: ColoredBox(color: subproject.effectiveColor!),
                    ),
                  ),
              ],
            ),
          );
        }, childCount: project.subprojects.length),
      ),
    ];
  }

  Widget _buildTaskList(WidgetRef ref, List<Task> tasks) {
    return SliverReorderableList(
      proxyDecorator: (child, index, animation) => _DragProxy(child: child),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return ReorderableDelayedDragStartListener(
          key: Key('task_${task.id}'),
          index: index,
          child: _buildTile(ref, task),
        );
      },
      itemCount: tasks.length,
      onReorder: (oldIndex, newIndexRaw) {
        int newIndex = newIndexRaw;
        if (newIndex > oldIndex) {
          newIndex -= 1;
        }

        if (newIndex < -1) newIndex = -1;

        final taskList = List<Task>.from(tasks);
        final moved = taskList.removeAt(oldIndex);
        final insertIndex = newIndex == -1
            ? 0
            : newIndex.clamp(0, taskList.length);
        taskList.insert(insertIndex, moved);

        final before = insertIndex == 0
            ? null
            : taskList[insertIndex - 1].position;
        final after = insertIndex == taskList.length - 1
            ? null
            : taskList[insertIndex + 1].position;
        final newPos = calculateItemPosition(
          positionBefore: before,
          positionAfter: after,
        );

        ref
            .read(projectControllerProvider(project).notifier)
            .reorderTasks(
              project: project,
              newOrderedTasks: taskList,
              movedTaskId: moved.id,
              newPosition: newPos,
            )
            .then((success) {
              if (!success && ref.context.mounted) {
                ScaffoldMessenger.of(ref.context).showSnackBar(
                  const SnackBar(content: Text('Failed to reorder task')),
                );
              }
            });
      },
    );
  }

  Widget _buildTile(WidgetRef ref, Task task) {
    return TaskListItem(
      key: Key(task.id.toString()),
      task: task,
      onTap: () => _openTaskDetail(ref, task),
      onCheckedChanged: (value) async {
        var success = await ref
            .read(projectControllerProvider(project).notifier)
            .markAsDone(task);
        if (!success && ref.context.mounted) {
          ScaffoldMessenger.of(ref.context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(ref.context).failedToMarkDone),
            ),
          );
        }
      },
    );
  }

  Future<void> _openTaskDetail(WidgetRef ref, Task task) async {
    final result = await Navigator.push<TaskPageResult>(
      ref.context,
      MaterialPageRoute(builder: (_) => TaskDetailPage(task: task)),
    );
    if (result != null) {
      ref.read(projectControllerProvider(project).notifier).reload();
    }
  }

  void _navigateToDetail(BuildContext context, Project subproject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return TaskListPage(
            key: Key(subproject.id.toString()),
            initialProject: subproject,
          );
        },
      ),
    );
  }
}

class _DragProxy extends StatefulWidget {
  final Widget child;
  const _DragProxy({required this.child});

  @override
  State<_DragProxy> createState() => _DragProxyState();
}

class _DragProxyState extends State<_DragProxy> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(scale: 1.04, child: widget.child);
  }
}
