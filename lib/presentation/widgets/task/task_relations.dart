import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/pages/task/task_detail_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_page_result.dart';

String _relationKindLabel(BuildContext context, RelationKind kind) {
  final l10n = AppLocalizations.of(context);
  return switch (kind) {
    RelationKind.subtask => l10n.relationSubtask,
    RelationKind.parenttask => l10n.relationParentTask,
    RelationKind.related => l10n.relationRelated,
    RelationKind.duplicateof => l10n.relationDuplicateOf,
    RelationKind.duplicates => l10n.relationDuplicates,
    RelationKind.blocking => l10n.relationBlocking,
    RelationKind.blocked => l10n.relationBlocked,
    RelationKind.precedes => l10n.relationPrecedes,
    RelationKind.follows => l10n.relationFollows,
    RelationKind.copiedfrom => l10n.relationCopiedFrom,
    RelationKind.copiedto => l10n.relationCopiedTo,
    RelationKind.unknown => l10n.relationUnknown,
  };
}

class TaskRelations extends ConsumerStatefulWidget {
  final int taskId;
  final List<TaskRelation> initialRelations;

  const TaskRelations({
    super.key,
    required this.taskId,
    required this.initialRelations,
  });

  @override
  ConsumerState<TaskRelations> createState() => _TaskRelationsState();
}

class _TaskRelationsState extends ConsumerState<TaskRelations> {
  late List<TaskRelation> _relations;
  final Set<int> _loadingTaskIds = {};

  @override
  void initState() {
    super.initState();
    _relations = List.of(widget.initialRelations);
  }

  @override
  void didUpdateWidget(TaskRelations old) {
    super.didUpdateWidget(old);
    if (!identical(old.initialRelations, widget.initialRelations)) {
      _relations = List.of(widget.initialRelations);
    }
  }

  Future<void> _openRelatedTask(TaskRelation relation) async {
    if (_loadingTaskIds.contains(relation.otherTaskId)) return;
    setState(() => _loadingTaskIds.add(relation.otherTaskId));

    final response = await ref
        .read(taskRepositoryProvider)
        .getTask(relation.otherTaskId);

    if (!mounted) {
      return;
    }

    switch (response) {
      case SuccessResponse(:final body):
        final result = await Navigator.push<TaskPageResult>(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailPage(task: body)),
        );
        if (!mounted) return;
        setState(() => _loadingTaskIds.remove(relation.otherTaskId));
        _handleTaskPageResult(result, relation.otherTaskId);
      case ErrorResponse() || ExceptionResponse():
        setState(() => _loadingTaskIds.remove(relation.otherTaskId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).relationLoadError),
          ),
        );
    }
  }

  void _handleTaskPageResult(TaskPageResult? result, int otherTaskId) {
    if (result == null) return;

    switch (result) {
      case TaskEdited(:final task):
        setState(() {
          for (var i = 0; i < _relations.length; i++) {
            if (_relations[i].otherTaskId == otherTaskId) {
              final old = _relations[i];
              _relations[i] = TaskRelation(
                taskId: old.taskId,
                otherTaskId: old.otherTaskId,
                otherTaskTitle: task.title,
                otherTaskDone: task.done,
                relationKind: old.relationKind,
              );
            }
          }
        });
      case TaskDeleted():
        setState(() {
          _relations.removeWhere((r) => r.otherTaskId == otherTaskId);
        });
    }
  }

  Future<void> _deleteRelation(TaskRelation relation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteRelationTitle),
        content: Text(AppLocalizations.of(context).deleteRelationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final success = await ref
        .read(taskRelationRepositoryProvider)
        .delete(widget.taskId, relation.relationKind, relation.otherTaskId);

    if (!mounted) return;

    if (success.isSuccessful) {
      setState(() {
        _relations.removeWhere(
          (r) =>
              r.otherTaskId == relation.otherTaskId &&
              r.relationKind == relation.relationKind,
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).relationDeleteError),
        ),
      );
    }
  }

  void _showAddRelationSheet() {
    final outerMessenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddRelationSheet(
        taskId: widget.taskId,
        onRelationAdded: (relation) {
          setState(() {
            final isDuplicate = _relations.any(
              (r) =>
                  r.otherTaskId == relation.otherTaskId &&
                  r.relationKind == relation.relationKind,
            );
            if (!isDuplicate) {
              _relations.add(relation);
            }
          });
          Navigator.pop(context);
        },
        outerMessenger: outerMessenger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final grouped = groupBy<TaskRelation, RelationKind>(
      _relations,
      (r) => r.relationKind,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Text(l10n.relationships, style: theme.textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _showAddRelationSheet,
                tooltip: l10n.addRelationTooltip,
              ),
            ],
          ),
        ),
        if (_relations.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              l10n.noRelationships,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          Column(
            children: grouped.entries.map((entry) {
              final kind = entry.key;
              final relations = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      _relationKindLabel(context, kind),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  ...relations.map((relation) {
                    final isLoading = _loadingTaskIds.contains(
                      relation.otherTaskId,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        onTap: isLoading
                            ? null
                            : () => _openRelatedTask(relation),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                relation.otherTaskTitle,
                                style: TextStyle(
                                  decoration: relation.otherTaskDone
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  decorationColor: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.45),
                                  color: relation.otherTaskDone
                                      ? theme.colorScheme.onSurface.withValues(
                                          alpha: 0.45,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            if (isLoading)
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.close),
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteRelation(relation),
                                tooltip: l10n.delete,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _AddRelationSheet extends ConsumerStatefulWidget {
  final int taskId;
  final void Function(TaskRelation) onRelationAdded;
  final ScaffoldMessengerState outerMessenger;

  const _AddRelationSheet({
    required this.taskId,
    required this.onRelationAdded,
    required this.outerMessenger,
  });

  @override
  ConsumerState<_AddRelationSheet> createState() => _AddRelationSheetState();
}

class _AddRelationSheetState extends ConsumerState<_AddRelationSheet> {
  RelationKind _selectedKind = RelationKind.related;
  Task? _selectedTask;
  List<Task>? _suggestedTasks;
  final _taskSearchController = TextEditingController();
  final _taskSearchFocusNode = FocusNode();
  Timer? _debounce;
  Completer<Iterable<String>>? _lastCompleter;
  bool _isLoading = false;
  bool _closeOnDismiss = false;

  @override
  void dispose() {
    _debounce?.cancel();
    if (_lastCompleter != null && !_lastCompleter!.isCompleted) {
      _lastCompleter!.complete(const Iterable<String>.empty());
    }
    _taskSearchController.dispose();
    _taskSearchFocusNode.dispose();
    super.dispose();
  }

  Future<List<String>> _searchTasks(String query) async {
    if (query.isEmpty) return [];

    final escapedQuery = query.replaceAll('"', '\\"');
    final response = await ref
        .read(taskRepositoryProvider)
        .getByFilterString('title ~ "$escapedQuery"');

    if (!mounted) return [];

    if (response.isSuccessful) {
      final tasks = response
          .toSuccess()
          .body
          .where((t) => t.id != widget.taskId)
          .toList();
      _suggestedTasks = tasks;
      return tasks.map((t) => t.title).toList();
    }

    return [];
  }

  Future<void> _addRelation() async {
    if (_selectedTask == null) return;

    final errorText = AppLocalizations.of(context).relationAddError;
    setState(() => _isLoading = true);

    try {
      final response = await ref
          .read(taskRelationRepositoryProvider)
          .create(widget.taskId, _selectedTask!.id, _selectedKind);

      if (response.isSuccessful) {
        if (!mounted) return;
        final relation = TaskRelation(
          taskId: widget.taskId,
          otherTaskId: _selectedTask!.id,
          otherTaskTitle: _selectedTask!.title,
          otherTaskDone: _selectedTask!.done,
          relationKind: _selectedKind,
        );
        widget.onRelationAdded(relation);
      } else {
        if (!mounted) return;
        if (_closeOnDismiss) {
          _closeOnDismiss = false;
          Navigator.pop(context);
          widget.outerMessenger.showSnackBar(
            SnackBar(content: Text(errorText)),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorText)));
        }
      }
    } finally {
      if (mounted && !_closeOnDismiss) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: _selectedTask == null || _isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedTask != null && !_isLoading) {
          _closeOnDismiss = true;
          _addRelation();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.addRelationship,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<RelationKind>(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).selectRelationKind,
                  border: const OutlineInputBorder(),
                ),
                initialValue: _selectedKind,
                items: RelationKind.values
                    .where((k) => k != RelationKind.unknown)
                    .map((kind) {
                      return DropdownMenuItem(
                        value: kind,
                        child: Text(_relationKindLabel(context, kind)),
                      );
                    })
                    .toList(),
                onChanged: (kind) {
                  if (kind != null) {
                    setState(() => _selectedKind = kind);
                  }
                },
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }

                  if (_debounce?.isActive ?? false) {
                    _debounce!.cancel();
                    _lastCompleter?.complete(const Iterable<String>.empty());
                  }

                  final completer = Completer<Iterable<String>>();
                  _lastCompleter = completer;

                  _debounce = Timer(
                    const Duration(milliseconds: 500),
                    () async {
                      final results = await _searchTasks(textEditingValue.text);
                      if (!completer.isCompleted) {
                        completer.complete(results);
                      }
                    },
                  );

                  return completer.future;
                },
                textEditingController: _taskSearchController,
                focusNode: _taskSearchFocusNode,
                onSelected: (String selection) {
                  final task = _suggestedTasks?.firstWhereOrNull(
                    (t) => t.title == selection,
                  );
                  if (task != null) {
                    setState(() {
                      _selectedTask = task;
                    });
                  }
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).searchTasksHint,
                          border: const OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
              ),
              if (_selectedTask != null) ...[
                const SizedBox(height: 12),
                Chip(
                  label: Text(_selectedTask!.title),
                  onDeleted: () {
                    setState(() => _selectedTask = null);
                    _taskSearchController.clear();
                  },
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading || _selectedTask == null
                      ? null
                      : _addRelation,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.add),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
