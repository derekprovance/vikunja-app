import 'package:flutter/material.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class TaskActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback? onBeforeAction;

  const TaskActions({super.key, required this.onEdit, this.onBeforeAction});

  void _edit() {
    onBeforeAction?.call();
    onEdit();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _edit,
      icon: const Icon(Icons.edit_outlined),
      tooltip: AppLocalizations.of(context).edit,
    );
  }
}
