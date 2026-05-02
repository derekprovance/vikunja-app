import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_page_model.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/empty_view.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_list_item.dart';
import 'package:vikunja_app/presentation/widgets/task/task_section_header.dart';
import 'package:vikunja_app/presentation/pages/task/task_detail_page.dart';

enum _TaskSection { overdue, today, tomorrow, thisWeek, later, noDueDate }

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    var pageModel = ref.watch(taskPageControllerProvider);

    return pageModel.when(
      data: (model) {
        return Scaffold(
          appBar: _buildAppBar(ref, context, model.onlyDueDate),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.read(taskPageControllerProvider.notifier).reload();
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.pixels ==
                    scrollInfo.metrics.maxScrollExtent) {
                  ref.read(taskPageControllerProvider.notifier).loadNextPage();
                }
                return false;
              },
              child: _buildList(ref, context, model),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              if (model.defaultProjectId == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.selectDefaultProject)),
                );
              } else {
                _addItemDialog(ref, context, model.defaultProjectId);
              }
            },
            child: const Icon(Icons.add),
          ),
        );
      },
      error: (err, _) => VikunjaErrorWidget(
        error: err,
        onRetry: () => ref.invalidate(taskPageControllerProvider),
      ),
      loading: () => const LoadingWidget(),
    );
  }

  Widget _buildList(WidgetRef ref, BuildContext context, TaskPageModel model) {
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
            (ctx, i) => _createListItem(ref, ctx, tasks[i]),
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

  AppBar _buildAppBar(WidgetRef ref, BuildContext context, bool onlyDueDate) {
    return AppBar(
      title: const Text("Vikunja"),
      actions: [
        Tooltip(
          message: AppLocalizations.of(context).onlyShowTasksWithDueDate,
          child: IconButton(
            icon: Icon(onlyDueDate ? Icons.filter_list : Icons.filter_list_alt),
            onPressed: () {
              _onlyDueDateChanged(ref, context, !onlyDueDate);
            },
          ),
        ),
      ],
    );
  }

  void _onlyDueDateChanged(WidgetRef ref, BuildContext context, bool newValue) {
    Navigator.pop(context);
    ref
        .read(taskPageControllerProvider.notifier)
        .setLandingPageOnlyDueDateTasks(newValue);
  }

  void _addItemDialog(
    WidgetRef ref,
    BuildContext context,
    int defaultProjectId,
  ) {
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) =>
            _addTask(ref, title, dueDate, defaultProjectId),
      ),
    );
  }

  Future<void> _addTask(
    WidgetRef ref,
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

    if (ref.context.mounted) {
      if (success) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(ref.context).taskAddedSuccess),
          ),
        );
      } else {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(ref.context).taskAddError),
          ),
        );
      }
    }
  }

  Widget _createListItem(WidgetRef ref, BuildContext context, Task task) {
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
              content: Text(AppLocalizations.of(context).taskMarkDoneError),
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
