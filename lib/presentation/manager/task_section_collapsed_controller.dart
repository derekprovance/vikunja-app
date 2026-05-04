import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';

part 'task_section_collapsed_controller.g.dart';

@riverpod
class TaskSectionCollapsedController extends _$TaskSectionCollapsedController {
  @override
  Future<Set<String>> build() =>
      ref.read(settingsRepositoryProvider).getCollapsedTaskSections();

  Future<void> toggle(String sectionName) async {
    final current = await future;
    final updated = Set<String>.from(current);
    if (!updated.remove(sectionName)) {
      updated.add(sectionName);
    }
    final previous = state;
    state = AsyncData(updated);
    try {
      await ref.read(settingsRepositoryProvider).setCollapsedTaskSections(updated);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}
