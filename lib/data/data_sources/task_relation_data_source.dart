import 'package:vikunja_app/core/network/remote_data_source.dart';
import 'package:vikunja_app/core/network/response.dart';
import 'package:vikunja_app/data/models/task_relation_dto.dart';

class TaskRelationDataSource extends RemoteDataSource {
  TaskRelationDataSource(super.client);

  Future<Response<TaskRelationDto>> create(
    int taskId,
    int otherTaskId,
    String relationKind,
  ) {
    return client.put(
      url: '/tasks/$taskId/relations',
      body: {'other_task_id': otherTaskId, 'relation_kind': relationKind},
      mapper: (body) => TaskRelationDto.fromJson(body),
    );
  }

  Future<Response<Object>> delete(
    int taskId,
    String relationKind,
    int otherTaskId,
  ) {
    return client.delete(
      url: '/tasks/$taskId/relations/$relationKind/$otherTaskId',
    );
  }
}
