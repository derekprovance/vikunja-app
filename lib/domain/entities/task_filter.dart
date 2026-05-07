import 'dart:convert';

import 'package:flutter/foundation.dart';

class TaskFilterScope {
  const TaskFilterScope._();

  static const String allTasks = 'all_tasks';

  static String project(int projectId) => 'project_$projectId';
}

enum DueDateFilter {
  overdue,
  today,
  thisWeek,
  hasDueDate,
  noDueDate,
}

class TaskFilter {
  final Set<int> priorities;
  final Set<int> labelIds;
  final DueDateFilter? dueDateFilter;

  const TaskFilter({
    this.priorities = const {},
    this.labelIds = const {},
    this.dueDateFilter,
  });

  static const TaskFilter empty = TaskFilter();

  bool get isActive =>
      priorities.isNotEmpty || labelIds.isNotEmpty || dueDateFilter != null;

  Map<String, dynamic> toJson() => {
    'priorities': priorities.toList(),
    'labelIds': labelIds.toList(),
    if (dueDateFilter != null) 'dueDateFilter': dueDateFilter!.name,
  };

  factory TaskFilter.fromJson(Map<String, dynamic> json) {
    DueDateFilter? dateFilter;
    if (json['dueDateFilter'] != null) {
      try {
        dateFilter = DueDateFilter.values.firstWhere(
          (e) => e.name == json['dueDateFilter'],
        );
      } catch (_) {
        dateFilter = null;
      }
    }
    return TaskFilter(
      priorities: Set<int>.from((json['priorities'] as List? ?? []).cast<int>()),
      labelIds: Set<int>.from((json['labelIds'] as List? ?? []).cast<int>()),
      dueDateFilter: dateFilter,
    );
  }

  static TaskFilter? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return TaskFilter.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  List<String> toFilterClauses() {
    final clauses = <String>[];

    if (priorities.isNotEmpty) {
      clauses.add('(${priorities.map((p) => "priority = $p").join(" || ")})');
    }

    if (labelIds.isNotEmpty) {
      clauses.add('(${labelIds.map((id) => "label_id = $id").join(" || ")})');
    }

    switch (dueDateFilter) {
      case DueDateFilter.hasDueDate:
        clauses.add("due_date > 0001-01-01 00:00");
      case DueDateFilter.noDueDate:
        clauses.add("due_date = 0001-01-01 00:00");
      case DueDateFilter.overdue:
        clauses.add("due_date < now");
      case DueDateFilter.today:
        // Vikunja DSL: now/d truncates to midnight; +1d = next midnight
        clauses.add("due_date > now/d && due_date < now/d+1d");
      case DueDateFilter.thisWeek:
        clauses.add("due_date > now/d && due_date < now/d+7d");
      case null:
        break;
    }

    return clauses;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskFilter &&
          runtimeType == other.runtimeType &&
          setEquals(priorities, other.priorities) &&
          setEquals(labelIds, other.labelIds) &&
          dueDateFilter == other.dueDateFilter;

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(priorities),
        Object.hashAllUnordered(labelIds),
        dueDateFilter,
      );
}
