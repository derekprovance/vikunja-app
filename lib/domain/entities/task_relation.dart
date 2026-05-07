enum RelationKind {
  subtask,
  parenttask,
  related,
  duplicateof,
  duplicates,
  blocking,
  blocked,
  precedes,
  follows,
  copiedfrom,
  copiedto,
  unknown;

  static RelationKind fromString(String value) =>
      RelationKind.values.firstWhere(
        (k) => k.name == value,
        orElse: () => RelationKind.unknown,
      );
}

class TaskRelation {
  final int taskId;
  final int otherTaskId;
  final String otherTaskTitle;
  final bool otherTaskDone;
  final RelationKind relationKind;

  TaskRelation({
    required this.taskId,
    required this.otherTaskId,
    required this.otherTaskTitle,
    required this.otherTaskDone,
    required this.relationKind,
  });
}
