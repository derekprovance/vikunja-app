import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class TaskSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isCollapsed;
  final VoidCallback? onTap;

  const TaskSectionHeader({
    super.key,
    required this.title,
    required this.count,
    this.isCollapsed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final caretIcon = isCollapsed
        ? (isRtl ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_right)
        : Icons.keyboard_arrow_down;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            if (onTap != null) ...[
              Icon(
                caretIcon,
                size: 18,
                color: primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: primary,
              ),
            ),
            const Spacer(),
            Badge(
              label: Text(
                count.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              backgroundColor: primary,
            ),
          ],
        ),
      ),
    );

    return SliverToBoxAdapter(
      child: onTap != null
          ? Semantics(
              button: true,
              expanded: !isCollapsed,
              label: '$title, ${AppLocalizations.of(context).taskSectionItemCount(count)}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: content),
              ),
            )
          : content,
    );
  }
}
