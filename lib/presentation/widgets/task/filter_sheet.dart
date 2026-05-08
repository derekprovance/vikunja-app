import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/task_filter.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
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
  Set<int> _selectedPriorities = {};
  Set<int> _selectedProjectIds = {};
  DueDateFilter? _selectedDueDateFilter;

  @override
  void initState() {
    super.initState();
    _initializeFilter();
  }

  Future<void> _initializeFilter() async {
    try {
      final currentFilter = await ref
          .read(taskFilterControllerProvider(widget.pageKey).future);
      if (mounted) {
        setState(() {
          _selectedPriorities = Set.from(currentFilter.priorities);
          _selectedProjectIds = Set.from(currentFilter.projectIds);
          _selectedDueDateFilter = currentFilter.dueDateFilter;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedPriorities = {};
          _selectedProjectIds = {};
          _selectedDueDateFilter = null;
        });
      }
    }
  }

  void _saveFilter() {
    final updated = TaskFilter(
      priorities: _selectedPriorities,
      projectIds: _selectedProjectIds,
      dueDateFilter: _selectedDueDateFilter,
    );
    ref.read(taskFilterControllerProvider(widget.pageKey).notifier)
        .updateFilter(updated);
  }

  void _clearFilter() {
    setState(() {
      _selectedPriorities = {};
      _selectedProjectIds = {};
      _selectedDueDateFilter = null;
    });
    _saveFilter();
  }

  bool get _isActive =>
      _selectedPriorities.isNotEmpty ||
      _selectedProjectIds.isNotEmpty ||
      _selectedDueDateFilter != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
              if (_isActive)
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
                        selected: _selectedPriorities.contains(priority),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedPriorities.add(priority);
                            } else {
                              _selectedPriorities.remove(priority);
                            }
                          });
                          _saveFilter();
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
                        .map((filter) => ChoiceChip(
                              selected: _selectedDueDateFilter == filter,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedDueDateFilter =
                                      selected ? filter : null;
                                });
                                _saveFilter();
                              },
                              label: Text(
                                _getDueDateLabel(context, filter),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  // Projects Section (only in All Tasks view)
                  if (widget.pageKey == TaskFilterScope.allTasks) ...[
                    _buildSectionLabel(context, l10n.filterProjects),
                    _buildProjectSection(ref),
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

  String _getDueDateLabel(BuildContext context, DueDateFilter filter) {
    final l10n = AppLocalizations.of(context);
    switch (filter) {
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

  Widget _buildProjectSection(WidgetRef ref) {
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
                    selected: _selectedProjectIds.contains(project.id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedProjectIds.add(project.id);
                        } else {
                          _selectedProjectIds.remove(project.id);
                        }
                      });
                      _saveFilter();
                    },
                    label: Text(project.title, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
        );
      },
    );
  }

  List<Project> _flattenProjects(Iterable<Project> projects) {
    final result = <Project>[];
    for (final p in projects) {
      result.add(p);
      result.addAll(_flattenProjects(p.subprojects));
    }
    return result;
  }
}
