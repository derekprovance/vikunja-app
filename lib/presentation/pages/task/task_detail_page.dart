import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/core/utils/misc.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/core/utils/repeat_after_parse.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_page_result.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/task/task_attachment_preview.dart';
import 'package:vikunja_app/presentation/widgets/task/task_comments.dart';

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

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Future<void> _openEdit() async {
    final result = await Navigator.push<TaskPageResult>(
      context,
      MaterialPageRoute(builder: (_) => TaskEditPage(task: _task)),
    );
    if (result is TaskDeleted && mounted) {
      Navigator.pop(context, const TaskDeleted());
    } else if (result is TaskEdited && mounted) {
      setState(() {
        _task = result.task;
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

  Widget _buildTaskHeader(ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: theme.textTheme.headlineSmall!.copyWith(
                decoration: _task.done
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: theme.colorScheme.onSurface.withValues(
                  alpha: 0.45,
                ),
                color: _task.done
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                    : theme.colorScheme.onSurface,
              ),
              child: Text(
                _task.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: l10n.done,
            child: InkWell(
              onTap: _isTogglingDone ? null : _toggleDone,
              borderRadius: BorderRadius.circular(22),
              child: AnimatedOpacity(
                opacity: _isTogglingDone ? 0.6 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                    color: _task.done
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _task.done
                        ? Icon(
                            Icons.check,
                            key: const ValueKey('check'),
                            color: theme.colorScheme.onPrimary,
                            size: 22,
                          )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_modified,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.pop(context, TaskEdited(_task));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.taskDetail),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: _buildContent(context, l10n, theme),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          onPressed: _openEdit,
          tooltip: l10n.edit,
          child: const Icon(Icons.edit_outlined),
        ),
      ),
    );
  }

  List<Widget> _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final widgets = <Widget>[];

    // Task title + done checkmark
    widgets.add(_buildTaskHeader(theme, l10n));

    // Future slot: status chips (todo/in-progress/done) go here when API supports it

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

    // Metadata card — only rendered if at least one field has a value
    final metadataRows = _buildMetadataRows(l10n);
    if (metadataRows.isNotEmpty) {
      widgets.add(Card(child: Column(children: metadataRows)));
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
      widgets.add(
        TaskAttachmentSection(attachments: _task.attachments, taskId: _task.id),
      );
      widgets.add(const SizedBox(height: 8));
    }

    // Description — only if non-empty
    if (stripHtml(_task.description).isNotEmpty) {
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

    // Info section at the bottom
    final infoSection = _buildInfoSection(l10n, theme);
    if (infoSection != null) {
      widgets.add(infoSection);
      widgets.add(const SizedBox(height: 16));
    }

    // Comments section
    widgets.add(TaskComments(taskId: _task.id));

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

  Widget? _buildInfoSection(AppLocalizations l10n, ThemeData theme) {
    final rows = <({String label, String value})>[];

    // Created by + date — only if timestamp is real (not year-0001 sentinel)
    if (_task.created.year > 1) {
      final createdBy = _task.createdBy;
      final authorName = createdBy != null
          ? (createdBy.name.isNotEmpty ? createdBy.name : createdBy.username)
          : null;
      final createdLabel = authorName != null
          ? '$authorName · ${_task.created.toLocal().formatShort()}'
          : _task.created.toLocal().formatShort();
      rows.add((label: l10n.taskInfoCreatedBy, value: createdLabel));
    }

    // Last updated (relative) — only if timestamp is real.
    // durationToHumanReadable expects target.difference(now): negative=past ("X ago"),
    // positive=future ("in X"). Treat tiny |delta| (incl. clock skew) as "Just now".
    if (_task.updated.year > 1) {
      final delta = _task.updated.difference(DateTime.now());
      final relative = delta.inSeconds.abs() < 5
          ? l10n.justNow
          : durationToHumanReadable(delta);
      rows.add((label: l10n.taskInfoUpdated, value: relative));
    }

    // Repeat interval — only if set
    final repeat = _task.repeatAfter;
    if (repeat != null && repeat.inSeconds > 0) {
      final value = getRepeatAfterValueFromDuration(repeat);
      final unit = getRepeatAfterTypeFromDuration(repeat);
      rows.add((
        label: l10n.taskInfoRepeats,
        value: '$value ${unit.toLocalizedString(context)}',
      ));
    }

    if (rows.isEmpty) return null;

    final mutedStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows.map((row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(row.label, style: mutedStyle),
                  ),
                  Expanded(child: Text(row.value, style: mutedStyle)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
