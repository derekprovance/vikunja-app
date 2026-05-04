import 'package:vikunja_app/domain/entities/task.dart';

sealed class TaskPageResult {
  const TaskPageResult();
}

class TaskEdited extends TaskPageResult {
  final Task task;

  const TaskEdited(this.task);
}

class TaskDeleted extends TaskPageResult {
  const TaskDeleted();
}
