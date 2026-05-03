import 'package:flutter/material.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

class VikunjaDateTimeField extends StatefulWidget {
  final String label;
  final IconData icon;
  final DateTime? initialValue;
  final void Function(DateTime?) onChanged;

  const VikunjaDateTimeField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.icon = Icons.date_range,
  });

  @override
  State<VikunjaDateTimeField> createState() => _VikunjaDateTimeFieldState();
}

class _VikunjaDateTimeFieldState extends State<VikunjaDateTimeField> {
  DateTime? _value;

  @override
  void initState() {
    super.initState();
    final v = widget.initialValue;
    _value = (v == null || v.year <= 1) ? null : v.toLocal();
  }

  @override
  void didUpdateWidget(covariant VikunjaDateTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      final v = widget.initialValue;
      _value = (v == null || v.year <= 1) ? null : v.toLocal();
    }
  }

  Future<void> _showPickers() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _value ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_value ?? DateTime.now()),
    );
    if (!mounted) return;
    if (time == null) return;

    final result = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _value = result);
    widget.onChanged(result);
  }

  void _clear() {
    setState(() => _value = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: _showPickers,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(widget.icon, color: colors.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _value != null ? _value!.formatShort() : '—',
                    style: textTheme.bodyMedium?.copyWith(
                      color: _value != null ? colors.onSurface : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (_value != null)
              IconButton(
                icon: const Icon(Icons.clear),
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                tooltip: AppLocalizations.of(context).clear,
                onPressed: _clear,
              ),
          ],
        ),
      ),
    );
  }
}
