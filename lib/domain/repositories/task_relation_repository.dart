import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';

abstract class TaskRelationRepository {
  Future<Response<TaskRelation>> create(
    int taskId,
    int otherTaskId,
    RelationKind kind,
  );

  Future<Response<Object>> delete(
    int taskId,
    RelationKind kind,
    int otherTaskId,
  );
}
