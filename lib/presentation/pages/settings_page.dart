import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vikunja_app/core/di/locale_provider.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/notification_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/core/utils/language_autonyms.dart';
import 'package:vikunja_app/core/utils/user_extensions.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/version.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/main.dart';
import 'package:vikunja_app/presentation/manager/settings_controller.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return SettingsPageState();
  }
}

class SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController durationTextController = TextEditingController();

  Version? newestVersion;
  late final Future<Map<String, String>> _headersFuture;

  @override
  void initState() {
    super.initState();
    _headersFuture = ref.read(clientProviderProvider).getHeaders();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);

    final l10n = AppLocalizations.of(context);
    final overrideLocale = ref.watch(localeOverrideProvider).asData?.value;
    final resolvedLocale = Localizations.localeOf(context);
    final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final bool isSystemSelected = overrideLocale == null;
    final bool isFallback =
        isSystemSelected &&
        platformLocale.languageCode != resolvedLocale.languageCode;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Text(l10n.settings),
      ),
      body: settings.when(
        data: (settings) {
          durationTextController.text = settings.refreshInterval.toString();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildProfileCard(context, settings.user, settings.projects),
              const SizedBox(height: 8),
              _sectionHeader(context, l10n.settingsAppearanceSection),
              _buildAppearanceCard(
                context,
                l10n,
                settings,
                isSystemSelected,
                overrideLocale,
                isFallback,
                platformLocale,
                resolvedLocale,
              ),
              const SizedBox(height: 8),
              _sectionHeader(context, l10n.settingsNetworkSection),
              _buildNetworkCard(context, l10n, settings),
              const SizedBox(height: 8),
              _sectionHeader(context, l10n.settingsNotificationsSection),
              _buildNotificationsCard(context, l10n, settings),
              const SizedBox(height: 8),
              _sectionHeader(context, l10n.settingsAccountSection),
              _buildAccountCard(context, l10n),
              const SizedBox(height: 24),
            ],
          );
        },
        error: (err, _) => VikunjaErrorWidget(
          error: err,
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
        loading: () => const LoadingWidget(),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    User user,
    List<Project> projects,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: FutureBuilder(
                    future: _headersFuture,
                    builder: (context, asyncSnapshot) {
                      if (!asyncSnapshot.hasData || user.username.isEmpty) {
                        return const CircleAvatar(radius: 28);
                      }
                      final imageHeaders = Map<String, String>.from(
                        asyncSnapshot.data!,
                      )..remove('Content-Type');
                      return ClipOval(
                        child: SvgPicture.network(
                          user.avatarUrl(
                            ref.read(clientProviderProvider).apiBase,
                          ),
                          headers: imageHeaders,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          placeholderBuilder: (_) =>
                              const CircleAvatar(radius: 28),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '@${user.username}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildDefaultProjectTile(context, user, projects),
        ],
      ),
    );
  }

  Widget _buildDefaultProjectTile(
    BuildContext context,
    User user,
    List<Project> projects,
  ) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.folder_outlined),
      title: Text(AppLocalizations.of(context).defaultProject),
      trailing: DropdownButton<int>(
        items: [
          DropdownMenuItem(
            value: 0,
            child: Text(AppLocalizations.of(context).none),
          ),
          ...projects.map(
            (e) => DropdownMenuItem(value: e.id, child: Text(e.title)),
          ),
        ],
        value:
            projects.firstWhereOrNull(
                  (element) => element.id == user.settings?.defaultProjectId,
                ) !=
                null
            ? user.settings?.defaultProjectId
            : 0,
        onChanged: (int? value) {
          if (value != null && user.settings != null) {
            ref
                .read(settingsControllerProvider.notifier)
                .setDefaultProject(value);
          }
        },
      ),
    );
  }

  Widget _buildAppearanceCard(
    BuildContext context,
    AppLocalizations l10n,
    dynamic settings,
    bool isSystemSelected,
    Locale? overrideLocale,
    bool isFallback,
    Locale platformLocale,
    Locale resolvedLocale,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.theme),
            subtitle: SegmentedButton<FlutterThemeMode>(
              segments: [
                ButtonSegment(
                  value: FlutterThemeMode.system,
                  label: Text(l10n.system),
                  icon: const Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: FlutterThemeMode.light,
                  label: Text(l10n.light),
                  icon: const Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: FlutterThemeMode.dark,
                  label: Text(l10n.dark),
                  icon: const Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (Set<FlutterThemeMode> selection) {
                ref
                    .read(settingsControllerProvider.notifier)
                    .setThemeMode(selection.first);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(l10n.language),
            subtitle: isFallback
                ? Text(
                    'System language (${platformLocale.languageCode}${platformLocale.countryCode != null ? '-${platformLocale.countryCode}' : ''}) not supported. Using ${languageAutonym(resolvedLocale)}.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSystemSelected
                      ? l10n.systemLanguage
                      : languageAutonym(overrideLocale!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Icon(Icons.chevron_right_outlined),
              ],
            ),
            onTap: () => _showLanguagePicker(context, overrideLocale),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.palette_outlined),
            title: Text(l10n.dynamicColors),
            value: settings.dynamicColors,
            onChanged: (bool value) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .setDynamicColors(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkCard(
    BuildContext context,
    AppLocalizations l10n,
    dynamic settings,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.security_outlined),
            title: Text(l10n.ignoreCertificates),
            value: settings.ignoreCertificates,
            onChanged: (bool value) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .setIgnoreCertificates(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_outlined),
            title: Text(l10n.backgroundRefreshInterval),
            subtitle: Row(
              children: [
                Expanded(
                  child: TextField(
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    keyboardType: TextInputType.number,
                    controller: durationTextController,
                    decoration: InputDecoration(
                      isDense: true,
                      helperText: l10n.noLimitHelper,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .setRefreshInterval(
                          int.tryParse(durationTextController.value.text) ?? 0,
                        );
                  },
                  child: Text(l10n.save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard(
    BuildContext context,
    AppLocalizations l10n,
    dynamic settings,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: Text(l10n.getVersionNotifications),
            value: settings.versionNotifications,
            onChanged: (bool value) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .setVersionNotifications(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: Text(l10n.sendTestNotification),
            onTap: () async {
              var notifGranted = await Permission.notification.isGranted;
              if (notifGranted) {
                ref.read(notificationProvider)?.sendTestNotification();
              } else {
                var status = await Permission.notification.request();
                if (status.isGranted) {
                  ref.read(notificationProvider)?.sendTestNotification();
                } else if (status.isPermanentlyDenied && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.noNotificationPermission)),
                  );
                }
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: Text(l10n.checkForLatestVersion),
            onTap: () async {
              var newestVersion = await ref
                  .read(versionRepositoryProvider)
                  .getLatestVersionTag();
              if (newestVersion == null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context).versionCheckError,
                    ),
                  ),
                );
              } else {
                setState(() {
                  this.newestVersion = newestVersion;
                });
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outlined),
            title: Text(
              settings.currentVersion != null
                  ? l10n.currentVersionPrefix(
                      settings.currentVersion.toString(),
                    )
                  : l10n.currentVersionUnknown,
            ),
            subtitle: newestVersion != null
                ? Text(
                    l10n.latestVersionPrefix(newestVersion.toString()),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.logout_outlined, color: theme.colorScheme.error),
        title: Text(
          l10n.logout,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        onTap: () {
          ref.read(settingsRepositoryProvider).saveServer(null);
          ref.read(settingsRepositoryProvider).saveUserToken(null);
          ref.read(settingsRepositoryProvider).saveRefreshToken(null);

          globalNavigatorKey.currentState
            ?..popUntil((route) => route.isFirst)
            ..pushReplacementNamed('/login');
        },
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, Locale? currentLocale) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.language,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      RadioListTile<Locale?>(
                        title: Text(l10n.systemLanguage),
                        value: null,
                        groupValue: currentLocale,
                        onChanged: (_) {
                          ref
                              .read(localeOverrideProvider.notifier)
                              .setLocale(null);
                          Navigator.pop(sheetContext);
                        },
                      ),
                      ...AppLocalizations.supportedLocales.map(
                        (loc) => RadioListTile<Locale?>(
                          title: Text(languageAutonym(loc)),
                          value: loc,
                          groupValue: currentLocale,
                          onChanged: (val) {
                            ref
                                .read(localeOverrideProvider.notifier)
                                .setLocale(val);
                            Navigator.pop(sheetContext);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
