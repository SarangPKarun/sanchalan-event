import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

part 'roadmap.g.dart';

/// A task plus its dependency ids and denormalized category key. The two
/// dependency lists are only sent by some endpoints, so both default to empty.
@JsonSerializable()
class TaskWithDependencies {
  const TaskWithDependencies({
    required this.id,
    required this.eventGroupId,
    this.subEventId,
    required this.taskCategoryId,
    required this.name,
    this.description,
    required this.status,
    this.dueDate,
    required this.source,
    required this.ownerType,
    this.ownerUserId,
    this.linkedVendorId,
    this.linkedBudgetCategoryId,
    required this.createdAt,
    required this.updatedAt,
    required this.categoryKey,
    required this.dependsOnTaskIds,
    required this.dependentTaskIds,
  });
  factory TaskWithDependencies.fromJson(Map<String, dynamic> json) =>
      _$TaskWithDependenciesFromJson(json);
  final String id;
  final String eventGroupId;
  final String? subEventId;
  final String taskCategoryId;
  final String name;
  final String? description;
  final TaskStatus status;

  /// Date-only (YYYY-MM-DD) or null.
  final DateTime? dueDate;
  final TaskSource source;
  final TaskOwnerType ownerType;
  final String? ownerUserId;
  final String? linkedVendorId;
  final String? linkedBudgetCategoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String categoryKey;
  @JsonKey(defaultValue: <String>[])
  final List<String> dependsOnTaskIds;
  @JsonKey(defaultValue: <String>[])
  final List<String> dependentTaskIds;
  Map<String, dynamic> toJson() => _$TaskWithDependenciesToJson(this);
}

/// Response of PATCH/DELETE /tasks/:id (a plain task, no category key or dependency lists).
@JsonSerializable()
class Task {
  const Task({
    required this.id,
    required this.eventGroupId,
    this.subEventId,
    required this.taskCategoryId,
    required this.name,
    this.description,
    required this.status,
    this.dueDate,
    required this.source,
    required this.ownerType,
    this.ownerUserId,
    this.linkedVendorId,
    this.linkedBudgetCategoryId,
    required this.createdAt,
    required this.updatedAt,
  });
  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
  final String id;
  final String eventGroupId;
  final String? subEventId;
  final String taskCategoryId;
  final String name;
  final String? description;
  final TaskStatus status;
  final DateTime? dueDate;
  final TaskSource source;
  final TaskOwnerType ownerType;
  final String? ownerUserId;
  final String? linkedVendorId;
  final String? linkedBudgetCategoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  Map<String, dynamic> toJson() => _$TaskToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ListEventGroupTasksResponse {
  const ListEventGroupTasksResponse({required this.tasks});
  factory ListEventGroupTasksResponse.fromJson(Map<String, dynamic> json) =>
      _$ListEventGroupTasksResponseFromJson(json);
  final List<TaskWithDependencies> tasks;
  Map<String, dynamic> toJson() => _$ListEventGroupTasksResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class GenerateRoadmapResponse {
  const GenerateRoadmapResponse({required this.tasks, this.removedTaskCount});
  factory GenerateRoadmapResponse.fromJson(Map<String, dynamic> json) =>
      _$GenerateRoadmapResponseFromJson(json);
  final List<TaskWithDependencies> tasks;

  /// Tasks soft-deleted by a re-run.
  final int? removedTaskCount;
  Map<String, dynamic> toJson() => _$GenerateRoadmapResponseToJson(this);
}

@JsonSerializable(includeIfNull: false)
class GenerateRoadmapBody {
  const GenerateRoadmapBody({this.mode});
  factory GenerateRoadmapBody.fromJson(Map<String, dynamic> json) =>
      _$GenerateRoadmapBodyFromJson(json);
  final RoadmapRegenMode? mode;
  Map<String, dynamic> toJson() => _$GenerateRoadmapBodyToJson(this);
}

/// Body of PATCH /tasks/:id. Set [clearDueDate] to send an explicit `dueDate: null`.
class UpdateTaskBody {
  const UpdateTaskBody({
    this.status,
    this.dueDate,
    this.clearDueDate = false,
    this.name,
    this.description,
    this.clearDescription = false,
    this.category,
  });

  /// Only notStarted, inProgress and done are accepted by the API.
  final TaskStatus? status;

  /// YYYY-MM-DD.
  final String? dueDate;
  final bool clearDueDate;
  final String? name;
  final String? description;
  final bool clearDescription;

  /// taskCategoryId (uuid) or categoryKey.
  final String? category;

  Map<String, dynamic> toJson() => {
        if (status != null) 'status': enumWireValue(status!),
        if (clearDueDate) 'dueDate': null else if (dueDate != null) 'dueDate': dueDate,
        if (name != null) 'name': name,
        if (clearDescription) 'description': null else if (description != null) 'description': description,
        if (category != null) 'category': category,
      };
}

@JsonSerializable(includeIfNull: false)
class CreateTaskBody {
  const CreateTaskBody({
    required this.name,
    required this.category,
    required this.dueDate,
    this.dependencyTaskIds,
  });
  factory CreateTaskBody.fromJson(Map<String, dynamic> json) => _$CreateTaskBodyFromJson(json);
  final String name;

  /// taskCategoryId (uuid) or categoryKey.
  final String category;

  /// YYYY-MM-DD.
  final String dueDate;
  final List<String>? dependencyTaskIds;
  Map<String, dynamic> toJson() => _$CreateTaskBodyToJson(this);
}

@JsonSerializable()
class TaskCategory {
  const TaskCategory({required this.id, required this.categoryKey});
  factory TaskCategory.fromJson(Map<String, dynamic> json) => _$TaskCategoryFromJson(json);
  final String id;
  final String categoryKey;
  Map<String, dynamic> toJson() => _$TaskCategoryToJson(this);
}

@JsonSerializable(explicitToJson: true)
class ListTaskCategoriesResponse {
  const ListTaskCategoriesResponse({required this.categories});
  factory ListTaskCategoriesResponse.fromJson(Map<String, dynamic> json) =>
      _$ListTaskCategoriesResponseFromJson(json);
  final List<TaskCategory> categories;
  Map<String, dynamic> toJson() => _$ListTaskCategoriesResponseToJson(this);
}
