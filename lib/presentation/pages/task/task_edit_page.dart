import 'dart:async';

import 'package:background_downloader/background_downloader.dart'
    show TaskStatus, FileDownloader;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/color_extensions.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/core/utils/repeat_after_parse.dart';
import 'package:vikunja_app/core/utils/repeat_after_unit.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_reminder.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/manager/projects_controller.dart';
import 'package:vikunja_app/presentation/pages/task/task_page_result.dart';
import 'package:vikunja_app/presentation/widgets/date_time_field.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/project/project_picker_sheet.dart';
import 'package:vikunja_app/presentation/widgets/task/color_picker_dialog.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  final Task task;

  TaskEditPage({required this.task}) : super(key: Key(task.toString()));

  @override
  TaskEditPageState createState() => TaskEditPageState();
}

class TaskEditPageState extends ConsumerState<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();

  String? _title;
  DateTime? _dueDate, _startDate, _endDate;
  int _repeatAfterValue = 0;
  RepeatAfterUnit _repeatAfterUnit = RepeatAfterUnit.days;
  int? _priority;
  int? _projectId;
  List<TaskReminder>? _reminderDates;
  List<Label>? _labels;
  Color? _color;
  double _percentDone = 0.0;

  // we use this to find the label object after a user taps on the suggestion, because the typeahead only uses strings, not full objects.
  List<Label>? _suggestedLabels;
  final _labelTypeAheadController = TextEditingController();

  Timer? _debounce;
  Completer<Iterable<String>>? _lastCompleter;

  Timer? _autoSaveDebounce;
  bool _isSaving = false;
  bool _saveQueued = false;
  Task? _lastSavedTask;
  bool _isPopping = false;
  Completer<void>? _saveCompleter;

  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _repeatValueFocusNode = FocusNode();

  @override
  void initState() {
    _title = widget.task.title;
    _reminderDates = List.of(widget.task.reminderDates);
    _labels = List.of(widget.task.labels);

    _priority = widget.task.priority;
    _projectId = widget.task.projectId;
    _color = widget.task.color;

    _dueDate = widget.task.dueDate;
    _startDate = widget.task.startDate;
    _endDate = widget.task.endDate;

    _percentDone = widget.task.percentDone ?? 0.0;

    _repeatAfterValue = getRepeatAfterValueFromDuration(
      widget.task.repeatAfter,
    );
    _repeatAfterUnit = getRepeatAfterTypeFromDuration(widget.task.repeatAfter);

    _titleFocusNode.addListener(() {
      if (!_titleFocusNode.hasFocus) {
        unawaited(_flushDebounce());
      }
    });
    _repeatValueFocusNode.addListener(() {
      if (!_repeatValueFocusNode.hasFocus) {
        unawaited(_flushDebounce());
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autoSaveDebounce?.cancel();
    _titleFocusNode.dispose();
    _repeatValueFocusNode.dispose();
    _labelTypeAheadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop || _isPopping) return;
        _isPopping = true;
        try {
          await _flushDebounce();
          if (_saveCompleter != null) {
            await _saveCompleter!.future;
          }
        } finally {
          if (mounted) {
            Navigator.of(
              context,
            ).pop(_lastSavedTask != null ? TaskEdited(_lastSavedTask!) : null);
          }
        }
      },
      child: Scaffold(appBar: _buildAppBar(), body: _buildForm(context)),
    );
  }

  AppBar _buildAppBar() {
    final bgColor = (_color != null && _color != Colors.black)
        ? _color
        : Theme.of(context).colorScheme.surface;
    final textColor = bgColor!.contrastTextColor;
    return AppBar(
      backgroundColor: bgColor,
      foregroundColor: textColor,
      title: Text(AppLocalizations.of(context).editTaskTitle),
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Form _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 50),
        children: <Widget>[
          _buildTitle(),
          _buildProject(),
          _buildDueDate(),
          _buildStartDate(),
          _buildEndDate(),
          _buildRepeatAfter(),
          _buildReminderList(),
          _buildAddReminderButton(context),
          _buildPriority(),
          _buildProgressSlider(),
          _buildAddLabel(context),
          _buildLabelList(),
          _buildColor(),
          _buildAttachments(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        maxLines: null,
        keyboardType: TextInputType.multiline,
        focusNode: _titleFocusNode,
        initialValue: widget.task.title,
        onChanged: (title) {
          _title = title;
          _scheduleAutoSave();
        },
        decoration: InputDecoration(
          labelText: AppLocalizations.of(context).title,
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildProject() {
    final projectsAsync = ref.watch(projectsControllerProvider);
    return projectsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (model) {
        final flatProjects = model.projects
            .expand((p) => _flattenProject(p, depth: 0))
            .toList();
        final currentProject = flatProjects.firstWhereOrNull(
          (p) => p.id == _projectId,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.folder_outlined),
            title: Text(AppLocalizations.of(context).project),
            trailing: Text(
              currentProject?.title ?? AppLocalizations.of(context).allTasks,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProjectPickerSheet(
                  currentProjectId: _projectId,
                  onSelected: (projectId) {
                    setState(() {
                      _projectId = projectId;
                    });
                    unawaited(_autoSave());
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<dynamic> _flattenProject(dynamic project, {required int depth}) {
    return [
      project,
      ...project.subprojects.expand(
        (sub) => _flattenProject(sub, depth: depth + 1),
      ),
    ];
  }

  Widget _buildDueDate() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: VikunjaDateTimeField(
        icon: Icons.access_time,
        label: AppLocalizations.of(context).dueDateLabel,
        initialValue: widget.task.dueDate,
        onChanged: (duedate) {
          _dueDate = duedate;
          _autoSave();
        },
      ),
    );
  }

  Widget _buildStartDate() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: VikunjaDateTimeField(
        label: AppLocalizations.of(context).startDateLabel,
        initialValue: widget.task.startDate,
        onChanged: (startDate) {
          _startDate = startDate;
          _autoSave();
        },
      ),
    );
  }

  Widget _buildEndDate() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: VikunjaDateTimeField(
        label: AppLocalizations.of(context).endDateLabel,
        initialValue: widget.task.endDate,
        onChanged: (endDate) {
          _endDate = endDate;
          _autoSave();
        },
      ),
    );
  }

  Widget _buildRepeatAfter() {
    var localizations = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Flexible(
            flex: 65,
            child: TextFormField(
              keyboardType: TextInputType.number,
              focusNode: _repeatValueFocusNode,
              initialValue: getRepeatAfterValueFromDuration(
                widget.task.repeatAfter,
              ).toString(),
              onChanged: (newValue) {
                _repeatAfterValue = int.tryParse(newValue) ?? 0;
                _scheduleAutoSave();
              },
              decoration: InputDecoration(
                labelText: localizations.repeatAfter,
                border: InputBorder.none,
                icon: Icon(Icons.repeat),
                contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
              ),
            ),
          ),
          Spacer(),
          Flexible(
            flex: 30,
            child: DropdownButtonFormField<RepeatAfterUnit>(
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
              ),
              isExpanded: true,
              initialValue: _repeatAfterUnit,
              onChanged: (RepeatAfterUnit? newType) {
                if (newType != null) {
                  _repeatAfterUnit = newType;
                  _autoSave();
                }
              },
              items: RepeatAfterUnit.values
                  .map<DropdownMenuItem<RepeatAfterUnit>>((
                    RepeatAfterUnit value,
                  ) {
                    return DropdownMenuItem<RepeatAfterUnit>(
                      value: value,
                      child: Text(value.toLocalizedString(context)),
                    );
                  })
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderList() {
    return Padding(
      padding: EdgeInsets.only(top: 8.0),
      child: Column(
        children:
            _reminderDates?.map((e) {
              return VikunjaDateTimeField(
                key: ObjectKey(e),
                label: AppLocalizations.of(context).reminder,
                initialValue: e.reminder,
                onChanged: (date) {
                  setState(() {
                    if (date != null) {
                      e.reminder = date;
                    } else {
                      _reminderDates?.remove(e);
                    }
                  });
                  _autoSave();
                },
              );
            }).toList() ??
            [],
      ),
    );
  }

  Widget _buildAddReminderButton(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _addNewReminder(context),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(Icons.alarm_add, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Text(
              AppLocalizations.of(context).addReminder,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriority() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        icon: const Icon(Icons.flag),
        labelText: AppLocalizations.of(context).priority,
        border: InputBorder.none,
      ),
      initialValue: priorityToString(AppLocalizations.of(context), _priority),
      isExpanded: true,
      onChanged: (String? newValue) {
        _priority = priorityFromString(AppLocalizations.of(context), newValue);
        _autoSave();
      },
      items:
          [
            AppLocalizations.of(context).priorityUnset,
            AppLocalizations.of(context).priorityLow,
            AppLocalizations.of(context).priorityMedium,
            AppLocalizations.of(context).priorityHigh,
            AppLocalizations.of(context).priorityUrgent,
            AppLocalizations.of(context).priorityDoNow,
          ].map((String value) {
            return DropdownMenuItem(value: value, child: Text(value));
          }).toList(),
    );
  }

  Widget _buildProgressSlider() {
    final percentText = '${(_percentDone * 100).toInt()}%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 15, left: 2),
            child: Icon(
              Icons.percent,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).progress,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
                Slider(
                  value: _percentDone,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: percentText,
                  onChanged: (double value) {
                    setState(() {
                      _percentDone = value;
                    });
                  },
                  onChangeEnd: (double value) {
                    _percentDone = value;
                    _autoSave();
                  },
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(percentText, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildAddLabel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 15, left: 2),
            child: Icon(
              Icons.label,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(
            width:
                MediaQuery.of(context).size.width -
                80 -
                ((IconTheme.of(context).size ?? 0) * 2),
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }

                if (_debounce?.isActive ?? false) {
                  _debounce!.cancel();
                  _lastCompleter?.complete(const Iterable<String>.empty());
                }

                final completer = Completer<Iterable<String>>();
                _lastCompleter = completer;

                _debounce = Timer(const Duration(milliseconds: 500), () async {
                  var labels = await _searchLabel(textEditingValue.text);
                  if (!completer.isCompleted) {
                    completer.complete(labels);
                  }
                });

                return completer.future;
              },
              focusNode: FocusNode(),
              textEditingController: _labelTypeAheadController,
              onSelected: (String selection) {
                _addLabel(selection);
              },
            ),
          ),
          IconButton(
            onPressed: () =>
                unawaited(_createAndAddLabel(_labelTypeAheadController.text)),
            icon: Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildColor() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 15, left: 2),
            child: Icon(
              Icons.palette,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          FilledButton.tonal(
            style: (_color == null || _color == Colors.black)
                ? null
                : FilledButton.styleFrom(backgroundColor: _color),
            onPressed: _onColorEdit,
            child: Text(
              AppLocalizations.of(context).setColor,
              style: (_color == null || _color == Colors.black)
                  ? null
                  : TextStyle(
                      color: _color!.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: () {
              Color? color = (_color == null || _color == Colors.black)
                  ? null
                  : _color;

              return Text(
                color != null
                    ? "#${color.toHexString()}"
                    : AppLocalizations.of(context).none,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              );
            }(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments() {
    return ListView.separated(
      separatorBuilder: (context, index) => Divider(),
      padding: const EdgeInsets.all(16.0),
      shrinkWrap: true,
      itemCount: widget.task.attachments.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(widget.task.attachments[index].file.name),
          trailing: IconButton(
            icon: Icon(Icons.download),
            onPressed: () async {
              var taskId = await ref
                  .read(taskRepositoryProvider)
                  .downloadAttachment(
                    widget.task.id,
                    widget.task.attachments[index],
                  );
              if (taskId.status == TaskStatus.complete) {
                FileDownloader().openFile(task: taskId.task);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildLabelList() {
    return Wrap(
      spacing: 10,
      children:
          _labels?.map((label) {
            return LabelWidget(
              label: label,
              onDelete: () => _removeLabel(label),
            );
          }).toList() ??
          [],
    );
  }

  Future<List<String>> _searchLabel(String query) async {
    var labelsResponse = await ref
        .read(labelRepositoryProvider)
        .getAll(query: query);

    if (labelsResponse.isSuccessful) {
      var labels = labelsResponse.toSuccess().body;

      labels.removeWhere(
        (labelToRemove) => _labels?.contains(labelToRemove) == true,
      );
      _suggestedLabels = labels;

      return labels.map((e) => e.title).toList();
    }
    return [];
  }

  void _addLabel(String labelTitle) {
    var label = _suggestedLabels?.firstWhereOrNull(
      (e) => e.title == labelTitle,
    );

    if (label != null) {
      setState(() {
        _labels?.add(label);
        _labelTypeAheadController.clear();
      });
      _autoSave();
    }
  }

  void _removeLabel(Label label) {
    setState(() {
      _labels?.removeWhere((l) => l.id == label.id);
    });
    _autoSave();
  }

  Future<void> _createAndAddLabel(String labelTitle) async {
    if (labelTitle.isEmpty ||
        _suggestedLabels?.firstWhereOrNull(
              (label) => label.title == labelTitle,
            ) !=
            null) {
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final newLabel = Label(title: labelTitle, createdBy: currentUser);
    final createdLabel = await ref
        .read(labelRepositoryProvider)
        .create(newLabel);

    if (!mounted || !createdLabel.isSuccessful) return;

    setState(() {
      _labels?.add(createdLabel.toSuccess().body);
      _labelTypeAheadController.clear();
    });
    await _autoSave();
  }

  Future<void> _addNewReminder(BuildContext context) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: todayStart,
      lastDate: DateTime(2100),
    );
    if (selectedDate == null) return;
    if (!mounted) return;

    final selectedTime = await showTimePicker(
      context: this.context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
    );
    if (selectedTime == null) return;
    if (!mounted) return;

    setState(() {
      _reminderDates?.add(
        TaskReminder(
          selectedDate.copyWith(
            hour: selectedTime.hour,
            minute: selectedTime.minute,
          ),
        ),
      );
    });
    _autoSave();
  }

  void _onColorEdit() {
    var pickerColor = _color ?? Colors.black;
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        pickerColor,
        (color) {
          if (color != Colors.black) {
            setState(() {
              _color = color;
            });
          } else {
            setState(() {
              _color = null;
            });
          }
          Navigator.of(context).pop();
          _autoSave();
        },
        () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Task _buildCurrentTask() {
    return (widget.task.copyWith(
        title: _title,
        reminderDates: _reminderDates,
        priority: _priority,
        projectId: _projectId,
        labels: _labels,
        repeatAfter: _repeatAfterUnit.getDuration(_repeatAfterValue),
        percentDone: widget.task.percentDone == null && _percentDone == 0.0
            ? null
            : _percentDone,
      ))
      ..dueDate = _dueDate
      ..startDate = _startDate
      ..endDate = _endDate
      ..color = _color;
  }

  void _scheduleAutoSave() {
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(const Duration(milliseconds: 800), _autoSave);
  }

  Future<void> _flushDebounce() async {
    if (_autoSaveDebounce?.isActive ?? false) {
      _autoSaveDebounce!.cancel();
      _autoSaveDebounce = null;
      await _autoSave();
    }
  }

  Future<void> _autoSave() async {
    if (_isSaving) {
      _saveQueued = true;
      return;
    }

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).endDateBeforeStartDate),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    _saveCompleter = Completer<void>();
    setState(() => _isSaving = true);

    try {
      final updatedTask = _buildCurrentTask();

      if (_labels != null) {
        final labelResult = await ref
            .read(taskLabelBulkRepositoryProvider)
            .update(updatedTask, _labels!);
        if (!labelResult.isSuccessful) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).taskSaveError),
              ),
            );
          }
          return;
        }
      }

      final saveSuccess = await ref
          .read(taskPageControllerProvider.notifier)
          .updateTask(updatedTask);

      if (mounted) {
        if (saveSuccess) {
          _lastSavedTask = updatedTask;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).taskSaveError)),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
      _saveCompleter?.complete();
      _saveCompleter = null;

      if (_saveQueued) {
        _saveQueued = false;
        unawaited(_autoSave());
      }
    }
  }
}
