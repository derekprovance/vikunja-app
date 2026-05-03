import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/project/project_edit.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/project_task_list.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task/task_section_header.dart';
import 'package:vikunja_app/presentation/pages/task/task_detail_page.dart';

enum _TaskSection { overdue, today, tomorrow, thisWeek, later, noDueDate }

// Pure testable functions
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
      final localDue = task.dueDate!.toLocal();
      final dueDateOnly = DateTime(
        localDue.year,
        localDue.month,
        localDue.day,
      );
      if (localDue.isBefore(now)) {
        grouped[_TaskSection.overdue]!.add(task);
      } else if (dueDateOnly == todayStart) {
        grouped[_TaskSection.today]!.add(task);
      } else if (dueDateOnly == tomorrowStart) {
        grouped[_TaskSection.tomorrow]!.add(task);
      } else if (!dueDateOnly.isBefore(dayAfterTomorrowStart) &&
          dueDateOnly.isBefore(weekEnd)) {
        grouped[_TaskSection.thisWeek]!.add(task);
      } else {
        grouped[_TaskSection.later]!.add(task);
      }
    }
  }

  return grouped;
}

String _getSectionTitle(AppLocalizations l10n, _TaskSection section) {
  return switch (section) {
    _TaskSection.overdue => l10n.overdue,
    _TaskSection.today => l10n.today,
    _TaskSection.tomorrow => l10n.tomorrow,
    _TaskSection.thisWeek => l10n.thisWeek,
    _TaskSection.later => l10n.later,
    _TaskSection.noDueDate => l10n.noDueDate,
  };
}

class TaskListPage extends ConsumerStatefulWidget {
  final Project? initialProject;

  const TaskListPage({super.key, this.initialProject});

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  int? _selectedProjectId;
  int _viewIndex = 0;
  NotificationHandler? _notificationHandler;

  @override
  void initState() {
    super.initState();
    if (widget.initialProject != null) {
      _selectedProjectId = widget.initialProject!.id;
    }
    // Always attach notification handler so picker-selected projects also reload
    _notificationHandler = ref.read(notificationProvider);
    _notificationHandler?.addListener(_onNotificationDone);
  }

  @override
  void dispose() {
    _notificationHandler?.removeListener(_onNotificationDone);
    super.dispose();
  }

  void _onNotificationDone() {
    final projectsData = ref.read(projectsControllerProvider);
    final project = _getSelectedProject(projectsData.value?.projects ?? []);
    if (project != null) {
      ref.read(projectControllerProvider(project).notifier).reload();
    }
  }

  bool get _isLocked => widget.initialProject != null;

  Future<void> _reloadProjectForView(Project project) async {
    if (project.views.isEmpty) {
      ref.read(projectControllerProvider(project).notifier).reload();
      return;
    }
    final safeIndex = _viewIndex.clamp(0, project.views.length - 1);
    return ref
        .read(projectControllerProvider(project).notifier)
        .loadForView(project, safeIndex);
  }

  Project? _getSelectedProject(Iterable<Project> projects) {
    if (_selectedProjectId == null) return null;
    for (final project in projects) {
      if (project.id == _selectedProjectId) return project;
      final found = _getSelectedProject(project.subprojects);
      if (found != null) return found;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selectedProjectId = _selectedProjectId;

    if (selectedProjectId == null) {
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
      // Project branch - look up fresh from projectsControllerProvider
      final projectsAsync = ref.watch(projectsControllerProvider);
      return projectsAsync.when(
        data: (projectsList) {
          final project = _getSelectedProject(projectsList.projects);

          if (project == null) {
            // Project not found - schedule state reset and show all tasks
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedProjectId = null);
            });
            // Temporarily show loading while state resets
            return const Scaffold(body: LoadingWidget());
          }

          final projectAsync = ref.watch(projectControllerProvider(project));
          return projectAsync.when(
            data: (data) => Scaffold(
              appBar: _buildProjectAppBar(data.project, data.displayDoneTask),
              body: NotificationListener<ScrollNotification>(
                onNotification: _handleProjectScroll,
                child: RefreshIndicator(
                  onRefresh: () => _reloadProjectForView(data.project),
                  child: _buildProjectBody(data.project),
                ),
              ),
              floatingActionButton: _buildProjectFab(data.project),
            ),
            error: (err, _) => VikunjaErrorWidget(
              error: err,
              onRetry: () => _reloadProjectForView(project),
            ),
            loading: () => const LoadingWidget(),
          );
        },
        error: (err, _) => VikunjaErrorWidget(error: err),
        loading: () => const Scaffold(body: LoadingWidget()),
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
            icon: Icon(
              model.onlyDueDate ? Icons.filter_list : Icons.filter_list_alt,
            ),
            onPressed: () {
              ref
                  .read(taskPageControllerProvider.notifier)
                  .setLandingPageOnlyDueDateTasks(!model.onlyDueDate);
            },
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // Project AppBar
  // ============================================================================

  AppBar _buildProjectAppBar(Project project, bool displayDoneTask) {
    final hasViews = project.views.isNotEmpty;
    final safeIndex = hasViews
        ? _viewIndex.clamp(0, project.views.length - 1)
        : 0;
    final title = _isLocked ? Text(project.title) : _buildProjectChip(project);
    return AppBar(
      title: title,
      actions: [
        if (hasViews && project.views.length >= 2)
          PopupMenuButton<int>(
            icon: project.views[safeIndex].icon,
            tooltip: project.views[safeIndex].title,
            onSelected: _onViewTapped,
            itemBuilder: (context) => project.views
                .asMap()
                .entries
                .map(
                  (entry) => PopupMenuItem<int>(
                    value: entry.key,
                    child: IconTheme(
                      data: IconThemeData(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      child: Row(
                        children: [
                          entry.value.icon,
                          const SizedBox(width: 12),
                          Text(entry.value.title),
                          if (entry.key == safeIndex) ...[
                            const Spacer(),
                            const Icon(Icons.check, size: 18),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
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
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
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
        currentProjectId: _selectedProjectId,
        onSelected: (projectId) {
          setState(() {
            _selectedProjectId = projectId;
            _viewIndex = 0;
          });
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
    final l10n = AppLocalizations.of(context);
    final slivers = <Widget>[];

    for (final section in _TaskSection.values) {
      final tasks = groupedTasks[section] ?? [];
      if (tasks.isEmpty) continue;

      final sectionTitle = _getSectionTitle(l10n, section);
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
      ViewKind.gantt || ViewKind.table => Center(
        child: Text(AppLocalizations.of(context).notImplemented),
      ),
    };
  }

  void _onViewTapped(int index) {
    final projectsData = ref.read(projectsControllerProvider);
    if (projectsData.value == null) return;

    final project = _getSelectedProject(projectsData.value!.projects);
    if (project == null) {
      setState(() => _selectedProjectId = null);
      return;
    }

    final safeIndex = index.clamp(0, project.views.length - 1);
    setState(() => _viewIndex = safeIndex);
    ref
        .read(projectControllerProvider(project).notifier)
        .loadForView(project, safeIndex);
  }

  // ============================================================================
  // FABs
  // ============================================================================

  Widget _buildAllTasksFab(TaskPageModel model) {
    return FloatingActionButton(
      heroTag: null,
      onPressed: () {
        if (model.defaultProjectId == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).selectDefaultProject),
            ),
          );
        } else {
          _addAllTasksDialog(model.defaultProjectId);
        }
      },
      child: const Icon(Icons.add),
    );
  }

  Widget? _buildProjectFab(Project project) {
    if (project.views.isEmpty || project.id < 0) return null;

    final safeIndex = _viewIndex.clamp(0, project.views.length - 1);
    if (project.views[safeIndex].viewKind == ViewKind.kanban) {
      return null;
    }

    return FloatingActionButton(
      heroTag: null,
      onPressed: () => _addProjectTaskDialog(project),
      child: const Icon(Icons.add),
    );
  }

  // ============================================================================
  // Scroll Notification Handlers
  // ============================================================================

  bool _handleAllTasksScroll(ScrollNotification scrollInfo) {
    if (scrollInfo is ScrollUpdateNotification &&
        scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
      ref.read(taskPageControllerProvider.notifier).loadNextPage();
    }
    return false;
  }

  bool _handleProjectScroll(ScrollNotification scrollInfo) {
    if (scrollInfo is ScrollUpdateNotification &&
        scrollInfo.metrics.axis == Axis.vertical &&
        scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
      final projectsData = ref.read(projectsControllerProvider);
      if (projectsData.value != null) {
        final project = _getSelectedProject(projectsData.value!.projects);
        if (project != null) {
          ref.read(projectControllerProvider(project).notifier).loadNextPage();
        }
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
        final result = await Navigator.push<Task?>(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailPage(task: task)),
        );
        if (result != null && result.done) {
          ref.read(taskPageControllerProvider.notifier).reload();
        }
      },
      onCheckedChanged: (value) async {
        var success = await ref
            .read(taskPageControllerProvider.notifier)
            .markAsDone(task);
        if (!success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).taskMarkDoneError),
            ),
          );
        }
      },
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
          SnackBar(content: Text(AppLocalizations.of(context).taskAddError)),
        );
      }
    }
  }

  // ============================================================================
  // Project Task Operations
  // ============================================================================

  void _addProjectTaskDialog(Project project) {
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) => _addProjectTask(project, title, dueDate),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppLocalizations.of(context).taskAddedSuccess
              : AppLocalizations.of(context).taskAddError,
        ),
      ),
    );
  }
}

// ============================================================================
// Project Picker Bottom Sheet
// ============================================================================

class _ProjectPickerSheet extends ConsumerWidget {
  final int? currentProjectId;
  final void Function(int?) onSelected;

  const _ProjectPickerSheet({
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
      leading: project.views.isNotEmpty
          ? project.views.first.icon
          : const Icon(Icons.folder_outlined),
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
