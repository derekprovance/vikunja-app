import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task_filter.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/main.dart' show globalSnackbarKey;
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/manager/task_filter_controller.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';

class FilterSheet extends ConsumerStatefulWidget {
  final String pageKey;

  const FilterSheet({required this.pageKey, super.key});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  Future<void> _saveFilter(TaskFilter filter) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(taskFilterControllerProvider(widget.pageKey).notifier)
          .updateFilter(filter);
    } catch (_) {
      if (!mounted) return;
      // Use global snackbar key to ensure the message appears even if the sheet is dismissed
      globalSnackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text(l10n.somethingWentWrong)),
      );
    }
  }

  void _clearFilter() {
    _saveFilter(TaskFilter.empty);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(taskFilterControllerProvider(widget.pageKey)).maybeWhen(
      data: (f) => f,
      orElse: () => TaskFilter.empty,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
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
        // Title row with Clear All button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.filterTasks,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (filter.isActive)
                TextButton(
                  onPressed: _clearFilter,
                  child: Text(l10n.filterClearAll),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Scrollable content
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Priority Section
                  _buildSectionLabel(context, l10n.priority),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: List.generate(5, (i) {
                      final priority = i + 1;
                      return FilterChip(
                        selected: filter.priorities.contains(priority),
                        onSelected: (selected) {
                          final newPriorities = Set<int>.from(filter.priorities);
                          if (selected) {
                            newPriorities.add(priority);
                          } else {
                            newPriorities.remove(priority);
                          }
                          _saveFilter(TaskFilter(
                            priorities: newPriorities,
                            projectIds: filter.projectIds,
                            dueDateFilter: filter.dueDateFilter,
                          ));
                        },
                        label: PriorityBatch(priority),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  // Due Date Section
                  _buildSectionLabel(context, l10n.dueDate),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: DueDateFilter.values
                        .map((ddf) => ChoiceChip(
                              selected: filter.dueDateFilter == ddf,
                              onSelected: (selected) {
                                _saveFilter(TaskFilter(
                                  priorities: filter.priorities,
                                  projectIds: filter.projectIds,
                                  dueDateFilter: selected ? ddf : null,
                                ));
                              },
                              label: Text(
                                _getDueDateLabel(context, ddf),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  // Projects Section (only in All Tasks view)
                  if (widget.pageKey == TaskFilterScope.allTasks) ...[
                    _buildSectionLabel(context, l10n.filterProjects),
                    _buildProjectSection(filter),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }

  String _getDueDateLabel(BuildContext context, DueDateFilter dueDateFilter) {
    final l10n = AppLocalizations.of(context);
    switch (dueDateFilter) {
      case DueDateFilter.overdue:
        return l10n.overdue;
      case DueDateFilter.today:
        return l10n.today;
      case DueDateFilter.thisWeek:
        return l10n.thisWeek;
      case DueDateFilter.hasDueDate:
        return l10n.filterHasDueDate;
      case DueDateFilter.noDueDate:
        return l10n.noDueDate;
    }
  }

  Widget _buildProjectSection(TaskFilter filter) {
    final projectsAsync = ref.watch(projectsControllerProvider);
    return projectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (model) {
        final allProjects = _flattenProjects(model.projects);
        if (allProjects.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              AppLocalizations.of(context).filterNoProjects,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: allProjects
              .map((project) => FilterChip(
                    selected: filter.projectIds.contains(project.id),
                    onSelected: (selected) {
                      final newProjectIds = Set<int>.from(filter.projectIds);
                      if (selected) {
                        newProjectIds.add(project.id);
                      } else {
                        newProjectIds.remove(project.id);
                      }
                      _saveFilter(TaskFilter(
                        priorities: filter.priorities,
                        projectIds: newProjectIds,
                        dueDateFilter: filter.dueDateFilter,
                      ));
                    },
                    label: Text(project.title, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        );
      },
    );
  }

  // Guard against cycles in malformed server data: a project listed as its own
  // (transitive) subproject would otherwise recurse infinitely.
  List<Project> _flattenProjects(Iterable<Project> projects, [Set<int>? seen]) {
    seen ??= {};
    final result = <Project>[];
    for (final p in projects) {
      if (seen.add(p.id)) {
        result.add(p);
        result.addAll(_flattenProjects(p.subprojects, seen));
      }
    }
    return result;
  }
}
