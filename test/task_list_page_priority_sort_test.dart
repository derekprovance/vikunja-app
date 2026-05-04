import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_grouping.dart';

Task _makeTask({
  required int id,
  String title = 'Test Task',
  int? priority,
  DateTime? created,
  DateTime? dueDate,
}) {
  return Task(
    id: id,
    title: title,
    priority: priority,
    created: created ?? DateTime.now(),
    dueDate: dueDate,
    createdBy: null,
    projectId: 1,
  );
}

void main() {
  group('Task grouping and priority sorting', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    test('ranked priority: DoNow > Urgent > High > Medium > Low > none', () {
      final tasks = [
        _makeTask(id: 1, priority: null, dueDate: tomorrow, created: now),
        _makeTask(id: 2, priority: 1, dueDate: tomorrow, created: now),
        _makeTask(id: 3, priority: 2, dueDate: tomorrow, created: now),
        _makeTask(id: 4, priority: 3, dueDate: tomorrow, created: now),
        _makeTask(id: 5, priority: 4, dueDate: tomorrow, created: now),
        _makeTask(id: 6, priority: 5, dueDate: tomorrow, created: now),
      ];

      final grouped = groupTasks(tasks);
      final sorted = grouped[TaskSection.tomorrow]!;

      expect(sorted[0].priority, 5, reason: 'Do Now (5) first');
      expect(sorted[1].priority, 4, reason: 'Urgent (4) second');
      expect(sorted[2].priority, 3, reason: 'High (3) third');
      expect(sorted[3].priority, 2, reason: 'Medium (2) fourth');
      expect(sorted[4].priority, 1, reason: 'Low (1) fifth');
      expect(sorted[5].priority, isNull, reason: 'No priority last');
    });

    test('equal priorities sorted by creation date (newest first)', () {
      final tasks = [
        _makeTask(
          id: 1,
          priority: 3,
          dueDate: tomorrow,
          created: now.subtract(const Duration(hours: 2)),
        ),
        _makeTask(
          id: 2,
          priority: 3,
          dueDate: tomorrow,
          created: now.subtract(const Duration(hours: 1)),
        ),
        _makeTask(
          id: 3,
          priority: 3,
          dueDate: tomorrow,
          created: now,
        ),
      ];

      final grouped = groupTasks(tasks);
      final sorted = grouped[TaskSection.tomorrow]!;

      expect(sorted[0].id, 3, reason: 'newest first');
      expect(sorted[1].id, 2);
      expect(sorted[2].id, 1, reason: 'oldest last');
    });

    test('priority=0 treated as no priority (does not float above null)', () {
      final tasks = [
        _makeTask(id: 1, priority: null, dueDate: tomorrow, created: now),
        _makeTask(id: 2, priority: 0, dueDate: tomorrow, created: now),
      ];

      final grouped = groupTasks(tasks);
      final sorted = grouped[TaskSection.tomorrow]!;

      // Both should be unprioritized and sort by creation date (newer first)
      expect(sorted[0].id, 2, reason: 'both are unprioritized, newer first');
      expect(sorted[1].id, 1);
    });

    test('unprioritized tasks in date sections sort by due date', () {
      final tasks = [
        _makeTask(
          id: 1,
          priority: null,
          dueDate: tomorrow.add(const Duration(hours: 5)),
        ),
        _makeTask(
          id: 2,
          priority: null,
          dueDate: tomorrow.add(const Duration(hours: 1)),
        ),
      ];

      final grouped = groupTasks(tasks);
      final sorted = grouped[TaskSection.tomorrow]!;

      expect(sorted[0].id, 2, reason: 'earlier due date first');
      expect(sorted[1].id, 1, reason: 'later due date last');
    });

    test('unprioritized tasks without due date sort by creation date (newest first)',
        () {
      final tasks = [
        _makeTask(
          id: 1,
          priority: null,
          created: now.subtract(const Duration(hours: 2)),
        ),
        _makeTask(
          id: 2,
          priority: null,
          created: now,
        ),
      ];

      final grouped = groupTasks(tasks);
      final sorted = grouped[TaskSection.noDueDate]!;

      expect(sorted[0].id, 2, reason: 'newer first');
      expect(sorted[1].id, 1, reason: 'older last');
    });

    test('priority overrides due date for sorting (same section)', () {
      final tasks = [
        _makeTask(id: 1, priority: null, dueDate: tomorrow),
        _makeTask(
          id: 2,
          priority: 1,
          dueDate: tomorrow,
          created: now.subtract(const Duration(hours: 1)),
        ),
      ];

      final grouped = groupTasks(tasks);
      final sorted = grouped[TaskSection.tomorrow]!;

      expect(sorted[0].id, 2, reason: 'prioritized task appears first');
      expect(sorted[1].id, 1, reason: 'unprioritized task appears last');
    });

    test('each section maintains independent ordering', () {
      final overdueLow = _makeTask(
        id: 1,
        priority: 1,
        dueDate: now.subtract(const Duration(hours: 1)),
      );
      final tomorrowHigh = _makeTask(
        id: 2,
        priority: 3,
        dueDate: tomorrow,
      );
      final overdueHigh = _makeTask(
        id: 3,
        priority: 3,
        dueDate: now.subtract(const Duration(hours: 1)),
      );

      final grouped = groupTasks([overdueLow, tomorrowHigh, overdueHigh]);

      // Overdue section should have High (3) before Low (1)
      final overdue = grouped[TaskSection.overdue]!;
      expect(overdue[0].id, 3, reason: 'High priority first in overdue');
      expect(overdue[1].id, 1, reason: 'Low priority second in overdue');

      // Tomorrow section should have High priority alone
      final tomorrowSection = grouped[TaskSection.tomorrow]!;
      expect(tomorrowSection[0].id, 2);
    });
  });
}
