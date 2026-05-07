import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/task_filter.dart';
import 'package:vikunja_app/domain/repositories/settings_repository.dart';
import 'package:vikunja_app/presentation/manager/task_section_collapsed_controller.dart';

class FakeSettingsRepository implements SettingsRepository {
  final Map<String, Set<String>> _store = {};

  @override
  Future<bool> getDisplayDoneTasks(int projectId) async => false;

  @override
  Future<bool> getDynamicColors() async => false;

  @override
  Future<bool> getIgnoreCertificates() async => false;

  @override
  Future<String?> getLocaleOverride() async => null;

  @override
  Future<List<String>> getPastServers() async => [];

  @override
  Future<int> getRefreshInterval() async => 0;

  @override
  Future<String?> getRefreshToken() async => null;

  @override
  Future<String?> getServer() async => null;

  @override
  Future<FlutterThemeMode> getThemeMode() async => FlutterThemeMode.system;

  @override
  Future<String?> getUserToken() async => null;

  @override
  Future<bool> getVersionNotifications() async => true;

  @override
  Future<bool> getLandingPageOnlyDueDateTasks() async => false;

  @override
  Future<void> setPastServers(List<String> server) async {}

  @override
  Future<void> saveRefreshToken(String? token) async {}

  @override
  Future<void> saveServer(String? server) async {}

  @override
  Future<void> saveUserToken(String? token) async {}

  @override
  Future<void> setDisplayDoneTasks(int projectId, bool value) async {}

  @override
  Future<void> setDynamicColors(bool dynamicColors) async {}

  @override
  Future<void> setIgnoreCertificates(bool value) async {}

  @override
  Future<void> setLandingPageOnlyDueDateTasks(bool value) async {}

  @override
  Future<void> setLocaleOverride(String? localeCode) async {}

  @override
  Future<void> setRefreshInterval(int minutes) async {}

  @override
  Future<void> setThemeMode(FlutterThemeMode newMode) async {}

  @override
  Future<void> setVersionNotifications(bool value) async {}

  Future<void> clearAuthData() async {}

  @override
  Future<Set<String>> getCollapsedTaskSections() async {
    return _store['collapsed'] ?? {};
  }

  @override
  Future<void> setCollapsedTaskSections(Set<String> sections) async {
    _store['collapsed'] = sections;
  }

  @override
  Future<TaskFilter> getTaskFilter(String pageKey) async => TaskFilter.empty;

  @override
  Future<void> setTaskFilter(String pageKey, TaskFilter filter) async {}
}

void main() {
  group('TaskSectionCollapsedController', () {
    test('build() returns the persisted set', () async {
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(),
          ),
        ],
      );

      final result = await container.read(taskSectionCollapsedControllerProvider.future);
      expect(result, isEmpty);
    });

    test('toggle() adds key when absent', () async {
      final fakeRepo = FakeSettingsRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      await container
          .read(taskSectionCollapsedControllerProvider.notifier)
          .toggle('today');
      final persisted = await fakeRepo.getCollapsedTaskSections();
      expect(persisted, contains('today'));
    });

    test('toggle() removes key when present', () async {
      final fakeRepo = FakeSettingsRepository();
      await fakeRepo.setCollapsedTaskSections({'today'});

      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      await container
          .read(taskSectionCollapsedControllerProvider.notifier)
          .toggle('today');
      final persisted = await fakeRepo.getCollapsedTaskSections();
      expect(persisted, isEmpty);
    });

    test('toggle() calls through to the repository', () async {
      final fakeRepo = FakeSettingsRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      await container
          .read(taskSectionCollapsedControllerProvider.notifier)
          .toggle('overdue');

      final persisted = await fakeRepo.getCollapsedTaskSections();
      expect(persisted, contains('overdue'));
      expect(persisted.length, 1);
    });
  });
}
