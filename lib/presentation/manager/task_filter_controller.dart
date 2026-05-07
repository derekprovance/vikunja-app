import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/domain/entities/task_filter.dart';

part 'task_filter_controller.g.dart';

@riverpod
class TaskFilterController extends _$TaskFilterController {
  @override
  Future<TaskFilter> build(String pageKey) =>
      ref.read(settingsRepositoryProvider).getTaskFilter(pageKey);

  Future<void> updateFilter(TaskFilter updated) async {
    final previous = state;
    state = AsyncData(updated);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .setTaskFilter(pageKey, updated);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> clearFilter() => updateFilter(TaskFilter.empty);
}
