import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/presentation/widgets/due_date_card.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/priority_batch.dart';
import 'package:vikunja_app/presentation/widgets/task/task_actions.dart';

class TaskListItem extends StatefulWidget {
  final Task task;
  final Function onTap;
  final Function onEdit;
  final Function(bool value) onCheckedChanged;

  const TaskListItem({
    super.key,
    required this.task,
    required this.onTap,
    required this.onEdit,
    required this.onCheckedChanged,
  });

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

    return GestureDetector(
      onTap: () => widget.onTap(),
      child: AnimatedOpacity(
        opacity: _isCompleting ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
          child: Stack(
            fit: StackFit.loose,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildCompleteButton(theme),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: theme.textTheme.bodyLarge!.copyWith(
                              decoration: _isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: _isDone
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.45,
                                    )
                                  : theme.colorScheme.onSurface,
                            ),
                            child: Text(
                              widget.task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TaskActions(
                          task: widget.task,
                          onEdit: () => widget.onEdit(),
                          variant: TaskActionsVariant.menu,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSecondRow(context),
                    if (widget.task.hasDueDate ||
                        (widget.task.priority != null &&
                            widget.task.priority != 0) ||
                        widget.task.attachments.isNotEmpty)
                      _buildThirdRow(context),
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
      ),
    );
  }

  Widget _buildCompleteButton(ThemeData theme) {
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
              ? Icon(
                  Icons.check,
                  key: const ValueKey('check'),
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }

  Widget _buildSecondRow(BuildContext context) {
    final projectName = widget.task.project?.title;
    final hasLabels = widget.task.labels.isNotEmpty;

    if (projectName == null && !hasLabels) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          if (projectName != null)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Text(
                projectName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (hasLabels)
            Expanded(
              child: Wrap(
                spacing: 4,
                runSpacing: 0,
                children: widget.task.labels
                    .map((label) => LabelWidget(label: label))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThirdRow(BuildContext context) {
    final hasDueDate = widget.task.hasDueDate;
    final hasPriority =
        widget.task.priority != null && widget.task.priority != 0;
    final hasAttachments = widget.task.attachments.isNotEmpty;

    return Row(
      children: [
        if (hasDueDate)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DueDateCard(widget.task.dueDate!),
          ),
        if (hasPriority)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PriorityBatch(widget.task.priority!),
          ),
        if (hasAttachments)
          Icon(
            Icons.attachment,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }
}
