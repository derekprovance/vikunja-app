import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/core/utils/mapping_extensions.dart';
import 'package:vikunja_app/data/data_sources/task_relation_data_source.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';
import 'package:vikunja_app/domain/repositories/task_relation_repository.dart';

class TaskRelationRepositoryImpl extends TaskRelationRepository {
  final TaskRelationDataSource _dataSource;

  TaskRelationRepositoryImpl(this._dataSource);

  @override
  Future<Response<TaskRelation>> create(
    int taskId,
    int otherTaskId,
    RelationKind kind,
  ) async {
    return (await _dataSource.create(
      taskId,
      otherTaskId,
      kind.name,
    )).toDomain();
  }

  @override
  Future<Response<Object>> delete(
    int taskId,
    RelationKind kind,
    int otherTaskId,
  ) {
    return _dataSource.delete(taskId, kind.name, otherTaskId);
  }
}
