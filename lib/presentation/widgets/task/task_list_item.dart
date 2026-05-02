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
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onTap(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      _buildCompleteButton(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
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
                      (widget.task.priority != null && widget.task.priority != 0))
                    _buildThirdRow(context),
                ],
              ),
            ),
            if (widget.task.color != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(width: 4.0, height: double.infinity, color: widget.task.color),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onCheckedChanged(!widget.task.done);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
          color: widget.task.done ? Theme.of(context).colorScheme.primary : Colors.transparent,
        ),
        child: widget.task.done
            ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 20)
            : null,
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
                children: widget.task.labels.map((label) => LabelWidget(label: label)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThirdRow(BuildContext context) {
    final hasDueDate = widget.task.hasDueDate;
    final hasPriority = widget.task.priority != null && widget.task.priority != 0;

    if (!hasDueDate && !hasPriority) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (hasDueDate)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: DueDateCard(widget.task.dueDate!),
          ),
        if (hasPriority) PriorityBatch(widget.task.priority!),
      ],
    );
  }
}
