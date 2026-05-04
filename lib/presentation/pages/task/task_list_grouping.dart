import 'package:vikunja_app/domain/entities/task.dart';

enum TaskSection { overdue, today, tomorrow, thisWeek, later, noDueDate }

extension TaskSectionStorageKey on TaskSection {
  String get storageKey => switch (this) {
    TaskSection.overdue => 'overdue',
    TaskSection.today => 'today',
    TaskSection.tomorrow => 'tomorrow',
    TaskSection.thisWeek => 'this_week',
    TaskSection.later => 'later',
    TaskSection.noDueDate => 'no_due_date',
  };
}

Map<TaskSection, List<Task>> groupTasks(List<Task> tasks) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final tomorrowStart = todayStart.add(const Duration(days: 1));
  final dayAfterTomorrowStart = todayStart.add(const Duration(days: 2));
  final weekEnd = todayStart.add(const Duration(days: 7));

  final grouped = <TaskSection, List<Task>>{};
  for (final section in TaskSection.values) {
    grouped[section] = [];
  }

  for (final task in tasks) {
    if (!task.hasDueDate) {
      grouped[TaskSection.noDueDate]!.add(task);
    } else {
      final localDue = task.dueDate!.toLocal();
      final dueDateOnly = DateTime(localDue.year, localDue.month, localDue.day);
      if (localDue.isBefore(now)) {
        grouped[TaskSection.overdue]!.add(task);
      } else if (dueDateOnly == todayStart) {
        grouped[TaskSection.today]!.add(task);
      } else if (dueDateOnly == tomorrowStart) {
        grouped[TaskSection.tomorrow]!.add(task);
      } else if (!dueDateOnly.isBefore(dayAfterTomorrowStart) &&
          dueDateOnly.isBefore(weekEnd)) {
        grouped[TaskSection.thisWeek]!.add(task);
      } else {
        grouped[TaskSection.later]!.add(task);
      }
    }
  }

  for (final section in TaskSection.values) {
    grouped[section]!.sort((a, b) {
      final aPriority = a.priority ?? 0;
      final bPriority = b.priority ?? 0;

      if (aPriority != bPriority) return bPriority.compareTo(aPriority);

      if (aPriority > 0) {
        final createdCmp = b.created.compareTo(a.created);
        if (createdCmp != 0) return createdCmp;
        return b.id.compareTo(a.id);
      }

      int cmp;
      if (section == TaskSection.noDueDate) {
        cmp = b.created.compareTo(a.created);
      } else {
        cmp = a.dueDate!.compareTo(b.dueDate!);
      }
      if (cmp != 0) return cmp;
      return b.id.compareTo(a.id);
    });
  }

  return grouped;
}
