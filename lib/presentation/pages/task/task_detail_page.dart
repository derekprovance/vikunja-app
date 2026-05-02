import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/pages/task/task_comments_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailPage({super.key, required this.task});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  late Task _task;
  bool _modified = false;
  bool _isTogglingDone = false;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Future<void> _openEdit() async {
    final editedTask = await Navigator.push<Task?>(
      context,
      MaterialPageRoute(builder: (_) => TaskEditPage(task: _task)),
    );
    if (editedTask != null && mounted) {
      setState(() {
        _task = editedTask;
        _modified = true;
      });
    }
  }

  Future<void> _toggleDone() async {
    if (_isTogglingDone) return;
    setState(() => _isTogglingDone = true);
    HapticFeedback.mediumImpact();

    final toggled = _task.copyWith(done: !_task.done);
    final response = await ref.read(taskRepositoryProvider).update(toggled);

    if (!mounted) return;
    if (response.isSuccessful) {
      setState(() {
        _task = toggled;
        _modified = true;
        _isTogglingDone = false;
      });
    } else {
      setState(() => _isTogglingDone = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).taskMarkDoneError)),
      );
    }
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TaskCommentsPage(taskId: _task.id, taskTitle: _task.title),
      ),
    );
  }

  void _closeFabAndExecute(VoidCallback action) {
    setState(() => _isFabExpanded = false);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_modified,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, _task);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _task.title,
            overflow: TextOverflow.ellipsis,
            style: _task.done
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          actions: [
            IconButton(
              icon: Icon(
                _task.done ? Icons.check_circle : Icons.check_circle_outline,
                color: _task.done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              onPressed: _toggleDone,
              tooltip: l10n.done,
            ),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
              children: _buildContent(context, l10n, theme),
            ),
            if (_isFabExpanded)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _isFabExpanded = false),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
        floatingActionButton: _buildSpeedDial(l10n, theme),
      ),
    );
  }

  List<Widget> _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final widgets = <Widget>[];

    // Labels at the top (if any)
    if (_task.labels.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _task.labels
                .map((label) => LabelWidget(label: label))
                .toList(),
          ),
        ),
      );
    }

    // Description — only if non-empty (trim to catch whitespace-only values)
    if (_task.description.trim().isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l10n.description, style: theme.textTheme.labelLarge),
        ),
      );
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 4),
          child: HtmlWidget(_task.description),
        ),
      );
    }

    // Metadata card — only rendered if at least one field has a value
    final metadataRows = _buildMetadataRows(l10n);
    if (metadataRows.isNotEmpty) {
      widgets.add(
        Card(
          child: Column(children: metadataRows),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    // Progress — only if > 0
    if (_task.percentDone != null && _task.percentDone! > 0) {
      widgets.add(
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: _task.percentDone,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(_task.percentDone! * 100).toInt()}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    // Reminders — only if any
    if (_task.reminderDates.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l10n.reminder, style: theme.textTheme.labelLarge),
        ),
      );
      for (final reminder in _task.reminderDates) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              children: [
                Icon(
                  Icons.alarm_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(reminder.reminder.toLocal().formatShort()),
              ],
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 8));
    }

    // Attachments — only if any
    if (_task.attachments.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l10n.file, style: theme.textTheme.labelLarge),
        ),
      );
      for (final attachment in _task.attachments) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 4),
            child: Row(
              children: [
                Icon(
                  Icons.attachment,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachment.file.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  /// Returns only the ListTiles that have meaningful values.
  List<Widget> _buildMetadataRows(AppLocalizations l10n) {
    final rows = <Widget>[];

    if (_task.hasDueDate) {
      rows.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.access_time_outlined),
          title: Text(l10n.dueDateLabel),
          trailing: Text(_task.dueDate!.toLocal().formatShort()),
        ),
      );
    }

    if (_task.hasStartDate) {
      rows.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.play_arrow_outlined),
          title: Text(l10n.startDateLabel),
          trailing: Text(_task.startDate!.toLocal().formatShort()),
        ),
      );
    }

    if (_task.hasEndDate) {
      rows.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.stop_outlined),
          title: Text(l10n.endDateLabel),
          trailing: Text(_task.endDate!.toLocal().formatShort()),
        ),
      );
    }

    final priority = _task.priority;
    if (priority != null && priority != 0) {
      rows.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.flag_outlined),
          title: Text(l10n.priority),
          trailing: Text(priorityToString(l10n, priority)),
        ),
      );
    }

    return rows;
  }

  Widget _buildSpeedDial(AppLocalizations l10n, ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Speed dial options (animated)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.bottomRight,
          child: _isFabExpanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDialItem(
                        heroTag: 'fab_edit',
                        icon: Icons.edit_outlined,
                        label: l10n.edit,
                        onTap: () =>
                            _closeFabAndExecute(() => _openEdit()),
                      ),
                      const SizedBox(height: 12),
                      _buildDialItem(
                        heroTag: 'fab_done',
                        icon: _task.done
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        label: l10n.done,
                        onTap: _isTogglingDone
                            ? null
                            : () => _closeFabAndExecute(() => _toggleDone()),
                      ),
                      const SizedBox(height: 12),
                      _buildDialItem(
                        heroTag: 'fab_comments',
                        icon: Icons.comment_outlined,
                        label: l10n.comments,
                        onTap: () =>
                            _closeFabAndExecute(() => _openComments()),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Main FAB
        FloatingActionButton(
          heroTag: 'fab_main',
          onPressed: () => setState(() => _isFabExpanded = !_isFabExpanded),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isFabExpanded
                ? const Icon(Icons.close, key: ValueKey('close'))
                : const Icon(Icons.more_vert, key: ValueKey('more')),
          ),
        ),
      ],
    );
  }

  Widget _buildDialItem({
    required String heroTag,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.small(
          heroTag: heroTag,
          onPressed: onTap,
          child: Icon(icon),
        ),
      ],
    );
  }
}
