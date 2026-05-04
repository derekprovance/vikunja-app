import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vikunja_app/core/utils/misc.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/widgets/due_date_card.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';

class TaskListItem extends StatefulWidget {
  final Task task;
  final VoidCallback onTap;
  final Function(bool value) onCheckedChanged;

  const TaskListItem({super.key, required this.task, required this.onTap, required this.onCheckedChanged});

  @override
  TaskListItemState createState() => TaskListItemState();
}

class TaskListItemState extends State<TaskListItem> {
  bool _isCompleting = false;
  Timer? _completionTimer;

  bool get _isDone => widget.task.done || _isCompleting;

  @override
  void dispose() {
    _completionTimer?.cancel();
    super.dispose();
  }

  void _onCircleTap() {
    if (widget.task.done) {
      HapticFeedback.mediumImpact();
      widget.onCheckedChanged(false);
      return;
    }

    if (_isCompleting) {
      _completionTimer?.cancel();
      HapticFeedback.lightImpact();
      setState(() => _isCompleting = false);
    } else {
      HapticFeedback.mediumImpact();
      setState(() => _isCompleting = true);
      _completionTimer = Timer(const Duration(milliseconds: 1200), () {
        widget.onCheckedChanged(true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Compute once to avoid repeated DateTime.now() calls across helper methods.
    final isOverdue = widget.task.hasDueDate && widget.task.dueDate!.isBefore(DateTime.now());
    final hasRepeat = widget.task.repeatAfter != null && widget.task.repeatAfter!.inSeconds > 0;
    final hasTopBadges = isOverdue || hasRepeat;

    // Badge straddle geometry: badge height ≈ 22px, half = 11px, card vertical margin = 4px.
    // badgeTopPadding reserves space above the Stack so badges don't clip into the card above.
    // badgeTopPosition = cardVerticalMargin(4) - halfBadge(11) = -7, centering the badge on the border.
    const badgeTopPadding = 11.0;
    const badgeTopPosition = -7.0;
    const badgeLeftPosition = 24.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _isCompleting ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: hasTopBadges ? const EdgeInsets.only(top: badgeTopPadding) : EdgeInsets.zero,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: Stack(
                  fit: StackFit.loose,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(12.0, hasTopBadges ? 19.0 : 10.0, 12.0, 10.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildAvatar(theme),
                          const SizedBox(width: 12),
                          Expanded(child: _buildContent(context, isOverdue: isOverdue)),
                          const SizedBox(width: 12),
                          _buildActions(theme),
                        ],
                      ),
                    ),
                    if (widget.task.color != null)
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        width: 4.0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                          child: Container(color: widget.task.color),
                        ),
                      ),
                  ],
                ),
              ),
              if (hasTopBadges)
                Positioned(
                  top: badgeTopPosition,
                  left: badgeLeftPosition,
                  child: _buildTopBadges(context, isOverdue: isOverdue, hasRepeat: hasRepeat),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBadges(BuildContext context, {required bool isOverdue, required bool hasRepeat}) {
    final theme = Theme.of(context);
    final badges = <Widget>[];

    if (isOverdue) {
      final difference = widget.task.dueDate!.difference(DateTime.now());
      badges.add(
        Container(
          decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            'Overdue ${durationToHumanReadable(difference)}',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    if (hasRepeat) {
      final interval = durationToHumanReadable(widget.task.repeatAfter!).replaceFirst('in ', '');
      badges.add(
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            'Every $interval',
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: badges);
  }

  Widget _buildAvatar(ThemeData theme) {
    final source = widget.task.project?.title ?? widget.task.title;
    final initial = source.isEmpty ? '?' : source.characters.first.toUpperCase();
    final bgColor = widget.task.color ?? theme.colorScheme.primaryContainer;

    return CircleAvatar(
      radius: 18,
      backgroundColor: bgColor,
      child: Text(
        initial,
        style: theme.textTheme.labelLarge?.copyWith(color: _contrastColor(bgColor), fontWeight: FontWeight.bold),
      ),
    );
  }

  // WCAG AA threshold: luminance of ~0.179 gives 4.5:1 contrast ratio against white/black.
  Color _contrastColor(Color background) {
    return background.computeLuminance() <= 0.179 ? Colors.white : Colors.black;
  }

  Widget _buildContent(BuildContext context, {required bool isOverdue}) {
    final theme = Theme.of(context);
    final hasPriority = widget.task.priority != null && widget.task.priority != 0;
    final hasUpcomingDueDate = widget.task.hasDueDate && !isOverdue;
    final hasLabels = widget.task.labels.isNotEmpty;
    final hasAttachments = widget.task.attachments.isNotEmpty;
    final hasMetadata = hasPriority || hasUpcomingDueDate || hasLabels || hasAttachments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: theme.textTheme.bodyLarge!.copyWith(
            decoration: _isDone ? TextDecoration.lineThrough : TextDecoration.none,
            color: _isDone ? theme.colorScheme.onSurface.withValues(alpha: 0.45) : theme.colorScheme.onSurface,
          ),
          child: Text(widget.task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        if (hasMetadata) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (hasPriority) PriorityBatch(widget.task.priority!),
              if (hasUpcomingDueDate) DueDateCard(widget.task.dueDate!),
              ...widget.task.labels.map((label) => LabelWidget(label: label, compact: true)),
              if (hasAttachments)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.attachment, size: 14, color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActions(ThemeData theme) {
    return InkWell(
      onTap: _onCircleTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.primary, width: 2),
          color: _isDone ? theme.colorScheme.primary : Colors.transparent,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isDone
              ? Icon(Icons.check, key: const ValueKey('check'), color: theme.colorScheme.onPrimary, size: 20)
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }
}
