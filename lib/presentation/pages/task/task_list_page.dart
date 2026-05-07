import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_filter.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/presentation/manager/project_controller.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/manager/task_filter_controller.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/manager/task_section_collapsed_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/project/project_edit.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/project_picker_sheet.dart';
import 'package:vikunja_app/presentation/widgets/project/project_task_list.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/filter_sheet.dart';
import 'package:vikunja_app/presentation/widgets/task/task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task/task_section_header.dart';
import 'package:vikunja_app/presentation/pages/task/task_detail_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_page_result.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_grouping.dart';

String _getSectionTitle(AppLocalizations l10n, TaskSection section) {
  return switch (section) {
    TaskSection.overdue => l10n.overdue,
    TaskSection.today => l10n.today,
    TaskSection.tomorrow => l10n.tomorrow,
    TaskSection.thisWeek => l10n.thisWeek,
    TaskSection.later => l10n.later,
    TaskSection.noDueDate => l10n.noDueDate,
  };
}

class TaskListPage extends ConsumerStatefulWidget {
  final Project? initialProject;

  const TaskListPage({super.key, this.initialProject});

  @override
  ConsumerState<TaskListPage> createState() => TaskListPageState();
}

class TaskListPageState extends ConsumerState<TaskListPage> {
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

  void resetToAllTasks() {
    if (_selectedProjectId == null) return;
    setState(() {
      _selectedProjectId = null;
      _viewIndex = 0;
    });
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
    final filterAsync = ref.watch(
      taskFilterControllerProvider(TaskFilterScope.allTasks),
    );
    final isActive = filterAsync.value?.isActive ?? false;

    return AppBar(
      title: _buildProjectChip(null),
      actions: [
        IconButton(
          icon: Icon(
            isActive ? Icons.filter_list : Icons.filter_list_outlined,
          ),
          tooltip: AppLocalizations.of(context).filterTasks,
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                const FilterSheet(pageKey: TaskFilterScope.allTasks),
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
    final filterAsync = ref.watch(
      taskFilterControllerProvider(TaskFilterScope.project(project.id)),
    );
    final isActive = filterAsync.value?.isActive ?? false;

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
          icon: Icon(
            isActive ? Icons.filter_list : Icons.filter_list_outlined,
          ),
          tooltip: AppLocalizations.of(context).filterTasks,
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                FilterSheet(pageKey: TaskFilterScope.project(project.id)),
          ),
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
      builder: (_) => ProjectPickerSheet(
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

    final groupedTasks = groupTasks(model.tasks);
    final l10n = AppLocalizations.of(context);
    final collapsedSectionsAsync = ref.watch(
      taskSectionCollapsedControllerProvider,
    );

    final collapsedSections = collapsedSectionsAsync.when(
      data: (sections) => sections,
      loading: () => const <String>{},
      error: (error, stackTrace) => const <String>{},
    );
    final slivers = <Widget>[];

    for (final section in TaskSection.values) {
      final tasks = groupedTasks[section] ?? [];
      if (tasks.isEmpty) continue;

      final isCollapsed = collapsedSections.contains(section.storageKey);
      final sectionTitle = _getSectionTitle(l10n, section);
      slivers.add(
        TaskSectionHeader(
          key: ValueKey('header_${section.storageKey}'),
          title: sectionTitle,
          count: tasks.length,
          isCollapsed: isCollapsed,
          onTap: () => ref
              .read(taskSectionCollapsedControllerProvider.notifier)
              .toggle(section.storageKey),
        ),
      );

      if (!isCollapsed) {
        slivers.add(
          SliverList(
            key: ValueKey('list_${section.storageKey}'),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _createListItem(ctx, tasks[i]),
              childCount: tasks.length,
            ),
          ),
        );
      }
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
        final result = await Navigator.push<TaskPageResult>(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailPage(task: task)),
        );
        if (result != null) {
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
