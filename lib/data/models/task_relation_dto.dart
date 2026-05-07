import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';

class TaskRelationDto extends Dto<TaskRelation> {
  final int taskId;
  final int otherTaskId;
  final String relationKind;
  final String otherTaskTitle;
  final bool otherTaskDone;

  TaskRelationDto({
    required this.taskId,
    required this.otherTaskId,
    required this.relationKind,
    this.otherTaskTitle = '',
    this.otherTaskDone = false,
  });

  TaskRelationDto.fromJson(Map<String, dynamic> json)
    : taskId = json['task_id'] as int,
      otherTaskId = json['other_task_id'] as int,
      relationKind = json['relation_kind'] as String,
      otherTaskTitle = json['other_task_title'] as String? ?? '',
      otherTaskDone = json['other_task_done'] as bool? ?? false;

  Map<String, dynamic> toJSON() => {
    'task_id': taskId,
    'other_task_id': otherTaskId,
    'relation_kind': relationKind,
  };

  @override
  TaskRelation toDomain() => TaskRelation(
    taskId: taskId,
    otherTaskId: otherTaskId,
    otherTaskTitle: otherTaskTitle,
    otherTaskDone: otherTaskDone,
    relationKind: _stringToRelationKind(relationKind),
  );

  static TaskRelationDto fromDomain(TaskRelation r) => TaskRelationDto(
    taskId: r.taskId,
    otherTaskId: r.otherTaskId,
    relationKind: r.relationKind.name,
    otherTaskTitle: r.otherTaskTitle,
    otherTaskDone: r.otherTaskDone,
  );

  static RelationKind _stringToRelationKind(String value) {
    try {
      return RelationKind.values.firstWhere((k) => k.name == value);
    } catch (_) {
      return RelationKind.unknown;
    }
  }
}
