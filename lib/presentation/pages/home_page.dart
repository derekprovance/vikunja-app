import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/constants.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/manager/notifications.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/project/project_list_page.dart';
import 'package:vikunja_app/presentation/pages/settings_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_list_page.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends ConsumerState<HomePage> {
  static const platform = MethodChannel('vikunja');

  int _selectedDrawerIndex = 0;
  NotificationHandler? _notificationHandler;

  final GlobalKey<TaskListPageState> _taskListKey =
      GlobalKey<TaskListPageState>();

  // Per-tab navigators: each tab has its own Navigator managed by IndexedStack.
  // In-tab navigation (Navigator.push within tab content) targets the nearest
  // ancestor Navigator, which is the tab's own navigator. Cross-app navigation
  // (auth redirects, logout) uses globalNavigatorKey to reach the MaterialApp navigator.
  final List<GlobalKey<NavigatorState>> _tabNavigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  List<NavigationDestination> navbarItems(BuildContext context) => [
    NavigationDestination(
      icon: Icon(Icons.home),
      label: AppLocalizations.of(context).homeTab,
    ),
    NavigationDestination(
      icon: Icon(Icons.folder_open),
      label: AppLocalizations.of(context).projectsTab,
    ),
    NavigationDestination(
      icon: Icon(Icons.settings),
      label: AppLocalizations.of(context).settingsTab,
    ),
  ];

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      scheduleIntent();
    });

    initNotifications();

    var settings = ref.read(settingsControllerProvider);
    settings.whenData((settings) {
      if (settings.versionNotifications) {
        postVersionCheckSnackbar();
      }
    });

    tz.initializeTimeZones();
  }

  @override
  void dispose() {
    _notificationHandler?.removeListener(onNotificationDone);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = _tabNavigatorKeys[_selectedDrawerIndex].currentState;
        if (navigator == null) return;
        if (navigator.canPop()) {
          await navigator.maybePop();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: NavigationBar(
            destinations: navbarItems(context),
            selectedIndex: _selectedDrawerIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedDrawerIndex = index;
              });
              if (index == 0) {
                _taskListKey.currentState?.resetToAllTasks();
              }
            },
          ),
        ),
        body: IndexedStack(
          index: _selectedDrawerIndex,
          children: [
            Navigator(
              key: _tabNavigatorKeys[0],
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => TaskListPage(key: _taskListKey),
                settings: settings,
              ),
            ),
            Navigator(
              key: _tabNavigatorKeys[1],
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const ProjectListPage(),
                settings: settings,
              ),
            ),
            Navigator(
              key: _tabNavigatorKeys[2],
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const SettingsPage(),
                settings: settings,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void scheduleIntent() async {
    try {
      String? argument = await platform.invokeMethod<String>("isQuickTile", "");

      return showAddItemDialog(argument);
    } catch (e) {
      developer.log("Error $e");
    }

    platform.setMethodCallHandler((call) async {
      return showAddItemDialog(call.arguments as String);
    });
  }

  Future<dynamic> showAddItemDialog(String? title) async {
    var response = await ref.read(userRepositoryProvider).getCurrentUser();
    var buildContext = context;
    if (response.isSuccessful && buildContext.mounted) {
      var defaultProjectId = response
          .toSuccess()
          .body
          .settings
          ?.defaultProjectId;
      if (defaultProjectId == null || defaultProjectId == 0) {
        ScaffoldMessenger.of(buildContext).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(buildContext).selectDefaultProject,
            ),
          ),
        );
      } else {
        _addItemDialog(buildContext, defaultProjectId, title);
        return Future.value();
      }
    }
  }

  void _addItemDialog(
    BuildContext context,
    int defaultProjectId, [
    String? title,
  ]) {
    showDialog(
      context: context,
      builder: (_) => AddTaskDialog(
        onAddTask: (title, dueDate) =>
            _addTask(title, dueDate, defaultProjectId, context),
        title: title,
      ),
    );
  }

  Future<void> _addTask(
    String title,
    DateTime? dueDate,
    int defaultProjectId,
    BuildContext context,
  ) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      return;
    }

    var task = Task(
      title: title,
      dueDate: dueDate,
      createdBy: currentUser,
      projectId: defaultProjectId,
    );

    var success = await ref
        .read(taskPageControllerProvider.notifier)
        .addTask(defaultProjectId, task);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).taskAddedSuccess),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).taskAddError)),
        );
      }
    }
  }

  Future<void> postVersionCheckSnackbar() async {
    var latestVersionTag = await ref
        .read(versionRepositoryProvider)
        .getLatestVersionTag();
    var currentVersionTag = await ref
        .read(versionRepositoryProvider)
        .getCurrentVersionTag();

    if (latestVersionTag != null &&
        currentVersionTag != null &&
        latestVersionTag.isNewerThan(currentVersionTag)) {
      final ctx = globalSnackbarKey.currentContext ?? context;

      if (ctx.mounted) {
        SnackBar snackBar = SnackBar(
          content: Text(
            AppLocalizations.of(
              ctx,
            ).newVersionAvailable(latestVersionTag.toString()),
          ),
          action: SnackBarAction(
            label: AppLocalizations.of(ctx).viewOnGithub,
            onPressed: () => launchUrl(
              Uri.parse(repo),
              mode: LaunchMode.externalApplication,
            ),
          ),
        );
        globalSnackbarKey.currentState?.showSnackBar(snackBar);
      }
    }
  }

  Future<void> initNotifications() async {
    var notifGranted = await Permission.notification.isGranted;
    if (notifGranted) {
      NotificationHandler notificationHandler = NotificationHandler();
      await notificationHandler.initNotifications();
      notificationHandler.addListener(onNotificationDone);

      ref.read(notificationProvider.notifier).set(notificationHandler);
      _notificationHandler = notificationHandler;

      _requestExactAlarmsPermission();
    }
  }

  void _requestExactAlarmsPermission() {
    try {
      final androidPlugin = FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      androidPlugin
          ?.canScheduleExactNotifications()
          .then((canExact) {
            if (canExact == false) {
              androidPlugin.requestExactAlarmsPermission();
            }
          })
          .catchError((e) {
            developer.log('Exact alarms permission request failed: $e');
          });
    } catch (e) {
      developer.log('Failed to request exact alarms permission: $e');
    }
  }

  void onNotificationDone() {
    ref.read(taskPageControllerProvider.notifier).reload();
  }
}
