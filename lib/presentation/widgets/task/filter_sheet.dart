import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task_filter.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/task_filter_controller.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';

class FilterSheet extends ConsumerStatefulWidget {
  final String pageKey;

  const FilterSheet({required this.pageKey, super.key});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late Set<int> _selectedPriorities;
  late Set<int> _selectedLabelIds;
  DueDateFilter? _selectedDueDateFilter;
  List<Label>? _labels;
  bool _labelsLoading = true;

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
          _selectedLabelIds = Set.from(currentFilter.labelIds);
          _selectedDueDateFilter = currentFilter.dueDateFilter;
        });
      }
    } catch (_) {
      // Fall back to empty if loading fails; UI will show empty state
      if (mounted) {
        setState(() {
          _selectedPriorities = {};
          _selectedLabelIds = {};
          _selectedDueDateFilter = null;
        });
      }
    }
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    try {
      final labelRepo = ref.read(labelRepositoryProvider);
      final response = await labelRepo.getAll();
      if (mounted && response.isSuccessful) {
        setState(() {
          _labels = response.toSuccess().body;
          _labelsLoading = false;
        });
      } else if (mounted) {
        setState(() => _labelsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _labelsLoading = false);
    }
  }

  Future<void> _applyFilter() async {
    final updated = TaskFilter(
      priorities: _selectedPriorities,
      labelIds: _selectedLabelIds,
      dueDateFilter: _selectedDueDateFilter,
    );
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(taskFilterControllerProvider(widget.pageKey).notifier)
          .updateFilter(updated);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).somethingWentWrong),
        ),
      );
      return;
    }
    if (!mounted) return;
    navigator.pop();
  }

  void _clearFilter() {
    setState(() {
      _selectedPriorities = {};
      _selectedLabelIds = {};
      _selectedDueDateFilter = null;
    });
  }

  bool get _isActive =>
      _selectedPriorities.isNotEmpty ||
      _selectedLabelIds.isNotEmpty ||
      _selectedDueDateFilter != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                                  selected:
                                      _selectedDueDateFilter == filter,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedDueDateFilter =
                                          selected ? filter : null;
                                    });
                                  },
                                  label: Text(
                                    _getDueDateLabel(context, filter),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      // Labels Section
                      _buildSectionLabel(context, l10n.filterLabels),
                      if (_labelsLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        )
                      else if (_labels == null || _labels!.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.filterNoLabels,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _labels!
                              .map((label) => FilterChip(
                                    selected:
                                        _selectedLabelIds.contains(label.id),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedLabelIds.add(label.id);
                                        } else {
                                          _selectedLabelIds
                                              .remove(label.id);
                                        }
                                      });
                                    },
                                    avatar: label.color != null
                                        ? CircleAvatar(
                                            backgroundColor: label.color,
                                            radius: 8,
                                          )
                                        : null,
                                    label: Text(label.title),
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 24),
                      // Apply button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _applyFilter,
                          child: Text(l10n.filterApply),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
}
