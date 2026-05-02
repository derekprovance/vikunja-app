import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/project/project_edit.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/project_task_list.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task/task_section_header.dart';
import 'package:vikunja_app/presentation/pages/task/task_detail_page.dart';

enum _TaskSection { overdue, today, tomorrow, thisWeek, later, noDueDate }

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  Project? _selectedProject;
  int _viewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final selectedProject = _selectedProject;

    if (selectedProject == null) {
      // All Tasks branch
      final pageModel = ref.watch(taskPageControllerProvider);
      return pageModel.when(
        data: (model) => Scaffold(
          appBar: _buildAllTasksAppBar(model),
          body: RefreshIndicator(
            onRefresh: () async =>
                ref.read(taskPageControllerProvider.notifier).reload(),
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleAllTasksScroll,
              child: _buildAllTasksBody(model),
            ),
          ),
          floatingActionButton: _buildAllTasksFab(model),
        ),
        error: (err, _) => VikunjaErrorWidget(
          error: err,
          onRetry: () => ref.invalidate(taskPageControllerProvider),
        ),
        loading: () => const LoadingWidget(),
      );
    } else {
      // Project branch
      final projectAsync = ref.watch(projectControllerProvider(selectedProject));
      return projectAsync.when(
        data: (data) => Scaffold(
          appBar: _buildProjectAppBar(data.project, data.displayDoneTask),
          body: NotificationListener<ScrollNotification>(
            onNotification: _handleProjectScroll,
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(projectControllerProvider(selectedProject).notifier)
                  .loadForView(data.project, _viewIndex),
              child: _buildProjectBody(data.project),
            ),
          ),
          floatingActionButton: _buildProjectFab(data.project),
          bottomNavigationBar: _buildBottomNavigation(data.project),
        ),
        error: (err, _) => VikunjaErrorWidget(
          error: err,
          onRetry: () => ref
              .read(projectControllerProvider(selectedProject).notifier)
              .loadForView(selectedProject, _viewIndex),
        ),
        loading: () => const LoadingWidget(),
      );
    }
  }

  // ============================================================================
  // All Tasks AppBar
  // ============================================================================

  AppBar _buildAllTasksAppBar(TaskPageModel model) {
    return AppBar(
      title: _buildProjectChip(null),
      actions: [
        Tooltip(
          message: AppLocalizations.of(context).onlyShowTasksWithDueDate,
          child: IconButton(
            icon: Icon(model.onlyDueDate
                ? Icons.filter_list
                : Icons.filter_list_alt),
            onPressed: () => _onlyDueDateChanged(!model.onlyDueDate),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // Project AppBar
  // ============================================================================

  AppBar _buildProjectAppBar(Project project, bool displayDoneTask) {
    return AppBar(
      title: _buildProjectChip(project),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectEditPage(
                project: project,
                displayDoneTask: displayDoneTask,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // Shared Project Chip (tappable title)
  // ============================================================================

  Widget _buildProjectChip(Project? project) {
    final l10n = AppLocalizations.of(context);
    final label = project?.title ?? l10n.allTasks;

    return InkWell(
      onTap: _showProjectPicker,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Project Picker
  // ============================================================================

  void _showProjectPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProjectPickerSheet(
        currentProject: _selectedProject,
        onSelected: (project) {
          setState(() {
            _selectedProject = project;
            _viewIndex = 0;
          });
          if (project != null) {
            ref
                .read(projectControllerProvider(project).notifier)
                .loadForView(project, 0);
          }
        },
      ),
    );
  }

  // ============================================================================
  // All Tasks Body (time-bucketed list)
  // ============================================================================

  Widget _buildAllTasksBody(TaskPageModel model) {
    if (model.tasks.isEmpty) {
      return EmptyView(Icons.list, AppLocalizations.of(context).noTasks);
    }

    final groupedTasks = _groupTasks(model.tasks);
    final slivers = <Widget>[];

    for (final section in _TaskSection.values) {
      final tasks = groupedTasks[section] ?? [];
      if (tasks.isEmpty) continue;

      final sectionTitle = _getSectionTitle(context, section);
      slivers.add(TaskSectionHeader(title: sectionTitle, count: tasks.length));

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _createListItem(ctx, tasks[i]),
            childCount: tasks.length,
          ),
        ),
      );
    }

    if (model.isLoadingNextPage) {
      slivers.add(
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

    return CustomScrollView(slivers: slivers);
  }

  // ============================================================================
  // Project Body (list or kanban view)
  // ============================================================================

  Widget _buildProjectBody(Project project) {
    if (project.views.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context).noViews));
    }

    final safeIndex = _viewIndex.clamp(0, project.views.length - 1);
    return switch (project.views[safeIndex].viewKind) {
      ViewKind.list => ProjectTaskList(project),
      ViewKind.kanban => KanbanWidget(project: project),
      _ => Center(child: Text(AppLocalizations.of(context).notImplemented)),
    };
  }

  // ============================================================================
  // Bottom Navigation (Project Views)
  // ============================================================================

  BottomNavigationBar? _buildBottomNavigation(Project project) {
    if (project.views.length < 2) return null;

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: project.views
          .map((view) => BottomNavigationBarItem(
                icon: view.icon,
                label: view.title,
                tooltip: view.title,
              ))
          .toList(),
      currentIndex: _viewIndex,
      onTap: _onViewTapped,
    );
  }

  void _onViewTapped(int index) {
    final project = _selectedProject;
    if (project == null) return;

    setState(() => _viewIndex = index);
    ref
        .read(projectControllerProvider(project).notifier)
        .loadForView(project, index);
  }

  // ============================================================================
  // FABs
  // ============================================================================

  Widget? _buildAllTasksFab(TaskPageModel model) {
    return FloatingActionButton(
      onPressed: () {
        if (model.defaultProjectId == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(AppLocalizations.of(context).selectDefaultProject)),
          );
        } else {
          _addAllTasksDialog(model.defaultProjectId);
        }
      },
      child: const Icon(Icons.add),
    );
  }

  Widget? _buildProjectFab(Project project) {
    if (project.views.isEmpty ||
        project.views[_viewIndex].viewKind == ViewKind.kanban ||
        project.id < 0) {
      return null;
    }

    return FloatingActionButton(
      onPressed: () => _addProjectTaskDialog(project),
      child: const Icon(Icons.add),
    );
  }

  // ============================================================================
  // Scroll Notification Handlers
  // ============================================================================

  bool _handleAllTasksScroll(ScrollNotification scrollInfo) {
    if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
      ref.read(taskPageControllerProvider.notifier).loadNextPage();
    }
    return false;
  }

  bool _handleProjectScroll(ScrollNotification scrollInfo) {
    if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
      final project = _selectedProject;
      if (project != null) {
        ref
            .read(projectControllerProvider(project).notifier)
            .loadNextPage();
      }
    }
    return false;
  }

  // ============================================================================
  // All Tasks Task Operations
  // ============================================================================

  Widget _createListItem(BuildContext context, Task task) {
    return TaskListItem(
      key: Key(task.id.toString()),
      task: task,
      onTap: () async {
        final result = await _openTaskDetail(context, task);
        if (result != null && result.done) {
          ref.read(taskPageControllerProvider.notifier).reload();
        }
      },
      onEdit: () => _onEdit(context, task),
      onCheckedChanged: (value) async {
        var success = await ref
            .read(taskPageControllerProvider.notifier)
            .markAsDone(task);
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(AppLocalizations.of(context).taskMarkDoneError),
            ),
          );
        }
      },
    );
  }

  Future<Task?> _openTaskDetail(BuildContext context, Task task) {
    return Navigator.push<Task?>(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailPage(task: task)),
    );
  }

  void _onEdit(BuildContext context, Task task) {
    Navigator.push<Task?>(
      context,
      MaterialPageRoute(builder: (buildContext) => TaskEditPage(task: task)),
    );
  }

  void _addAllTasksDialog(int defaultProjectId) {
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) =>
            _addAllTask(title, dueDate, defaultProjectId),
      ),
    );
  }

  Future<void> _addAllTask(
    String title,
    DateTime? dueDate,
    int defaultProjectId,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      return;
    }

    var task = Task(
      title: title,
      dueDate: dueDate,
      createdBy: currentUser,
      projectId: defaultProjectId,
    );

    var success = await ref
        .read(taskPageControllerProvider.notifier)
        .addTask(defaultProjectId, task);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).taskAddedSuccess),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).taskAddError),
          ),
        );
      }
    }
  }

  void _onlyDueDateChanged(bool newValue) {
    Navigator.pop(context);
    ref
        .read(taskPageControllerProvider.notifier)
        .setLandingPageOnlyDueDateTasks(newValue);
  }

  // ============================================================================
  // Project Task Operations
  // ============================================================================

  void _addProjectTaskDialog(Project project) {
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) =>
            _addProjectTask(project, title, dueDate),
      ),
    );
  }

  Future<void> _addProjectTask(
    Project project,
    String title,
    DateTime? dueDate,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      return;
    }

    final task = Task(
      title: title,
      dueDate: dueDate,
      createdBy: currentUser,
      done: false,
      projectId: project.id,
    );

    final success = await ref
        .read(projectControllerProvider(project).notifier)
        .addTask(project, task);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? AppLocalizations.of(context).taskAddedSuccess
          : AppLocalizations.of(context).taskAddError),
    ));
  }

  // ============================================================================
  // Task Grouping Helpers
  // ============================================================================

  Map<_TaskSection, List<Task>> _groupTasks(List<Task> tasks) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final dayAfterTomorrowStart = todayStart.add(const Duration(days: 2));
    final weekEnd = todayStart.add(const Duration(days: 7));

    final grouped = <_TaskSection, List<Task>>{};
    for (final section in _TaskSection.values) {
      grouped[section] = [];
    }

    for (final task in tasks) {
      if (!task.hasDueDate) {
        grouped[_TaskSection.noDueDate]!.add(task);
      } else {
        final dueDate = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        if (dueDate.isBefore(todayStart)) {
          grouped[_TaskSection.overdue]!.add(task);
        } else if (dueDate == todayStart) {
          grouped[_TaskSection.today]!.add(task);
        } else if (dueDate == tomorrowStart) {
          grouped[_TaskSection.tomorrow]!.add(task);
        } else if (!dueDate.isBefore(dayAfterTomorrowStart) &&
            dueDate.isBefore(weekEnd)) {
          grouped[_TaskSection.thisWeek]!.add(task);
        } else {
          grouped[_TaskSection.later]!.add(task);
        }
      }
    }

    return grouped;
  }

  String _getSectionTitle(BuildContext context, _TaskSection section) {
    final l10n = AppLocalizations.of(context);
    return switch (section) {
      _TaskSection.overdue => l10n.overdue,
      _TaskSection.today => l10n.today,
      _TaskSection.tomorrow => l10n.tomorrow,
      _TaskSection.thisWeek => l10n.thisWeek,
      _TaskSection.later => l10n.later,
      _TaskSection.noDueDate => l10n.noDueDate,
    };
  }
}

// ============================================================================
// Project Picker Bottom Sheet
// ============================================================================

class _ProjectPickerSheet extends ConsumerWidget {
  final Project? currentProject;
  final void Function(Project? project) onSelected;

  const _ProjectPickerSheet({
    required this.currentProject,
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                l10n.selectProject,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            // List
            Expanded(
              child: projectsAsync.when(
                data: (model) => ListView(
                  controller: scrollController,
                  children: [
                    _buildProjectItem(context, null),
                    ...model.projects
                        .expand((p) => _flattenProject(context, p)),
                  ],
                ),
                loading: () => const LoadingWidget(),
                error: (err, _) => VikunjaErrorWidget(error: err),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _flattenProject(BuildContext context, Project project) {
    return [
      _buildProjectItem(context, project),
      ...project.subprojects.expand((sub) => _flattenProject(context, sub)),
    ];
  }

  Widget _buildProjectItem(BuildContext context, Project? project) {
    final l10n = AppLocalizations.of(context);
    final isSelected = project?.id == currentProject?.id;

    return ListTile(
      leading: project == null
          ? const Icon(Icons.home_outlined)
          : (project.views.isNotEmpty
              ? project.views.first.icon
              : const Icon(Icons.folder_outlined)),
      title: Text(project?.title ?? l10n.allTasks),
      trailing: isSelected
          ? Icon(Icons.check,
              color: Theme.of(context).colorScheme.primary)
          : null,
      selected: isSelected,
      onTap: () {
        Navigator.pop(context);
        onSelected(project);
      },
    );
  }
}
