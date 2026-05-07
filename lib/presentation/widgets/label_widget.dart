import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/label.dart';

class LabelWidget extends StatelessWidget {
  final Label label;
  final VoidCallback? onDelete;

  /// When true and [onDelete] is null, renders as a compact [Badge] pill.
  /// Falls back to [Chip] when [onDelete] is provided (delete affordance requires chip shape).
  final bool compact;

  const LabelWidget({
    super.key,
    required this.label,
    this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact && onDelete == null) {
      return Badge(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        label: Text(label.title),
        backgroundColor:
            label.color ??
            Theme.of(context).colorScheme.surfaceContainerHighest,
        textColor:
            _getTextColor() ?? Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label.title, style: TextStyle(color: _getTextColor())),
      backgroundColor:
          label.color ?? Theme.of(context).colorScheme.surfaceBright,
      iconTheme: IconThemeData(color: _getTextColor()),
      onDeleted: onDelete,
    );
  }

  // WCAG AA threshold: luminance ≤ 0.179 gives 4.5:1 contrast ratio against white.
  Color? _getTextColor() {
    if (label.color != null) {
      return label.color!.computeLuminance() <= 0.179
          ? Colors.white
          : Colors.black;
    }
    return null;
  }
}
