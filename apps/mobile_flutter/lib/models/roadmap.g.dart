// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roadmap.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskWithDependencies _$TaskWithDependenciesFromJson(
  Map<String, dynamic> json,
) => TaskWithDependencies(
  id: json['id'] as String,
  eventGroupId: json['eventGroupId'] as String,
  subEventId: json['subEventId'] as String?,
  taskCategoryId: json['taskCategoryId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  status: $enumDecode(_$TaskStatusEnumMap, json['status']),
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  source: $enumDecode(_$TaskSourceEnumMap, json['source']),
  ownerType: $enumDecode(_$TaskOwnerTypeEnumMap, json['ownerType']),
  ownerUserId: json['ownerUserId'] as String?,
  linkedVendorId: json['linkedVendorId'] as String?,
  linkedBudgetCategoryId: json['linkedBudgetCategoryId'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
  categoryKey: json['categoryKey'] as String,
  dependsOnTaskIds:
      (json['dependsOnTaskIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
  dependentTaskIds:
      (json['dependentTaskIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      [],
);

Map<String, dynamic> _$TaskWithDependenciesToJson(
  TaskWithDependencies instance,
) => <String, dynamic>{
  'id': instance.id,
  'eventGroupId': instance.eventGroupId,
  'subEventId': instance.subEventId,
  'taskCategoryId': instance.taskCategoryId,
  'name': instance.name,
  'description': instance.description,
  'status': _$TaskStatusEnumMap[instance.status]!,
  'dueDate': instance.dueDate?.toIso8601String(),
  'source': _$TaskSourceEnumMap[instance.source]!,
  'ownerType': _$TaskOwnerTypeEnumMap[instance.ownerType]!,
  'ownerUserId': instance.ownerUserId,
  'linkedVendorId': instance.linkedVendorId,
  'linkedBudgetCategoryId': instance.linkedBudgetCategoryId,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'categoryKey': instance.categoryKey,
  'dependsOnTaskIds': instance.dependsOnTaskIds,
  'dependentTaskIds': instance.dependentTaskIds,
};

const _$TaskStatusEnumMap = {
  TaskStatus.notStarted: 'not_started',
  TaskStatus.inProgress: 'in_progress',
  TaskStatus.done: 'done',
  TaskStatus.overdue: 'overdue',
  TaskStatus.notApplicable: 'not_applicable',
};

const _$TaskSourceEnumMap = {
  TaskSource.aiGenerated: 'ai_generated',
  TaskSource.templateDefault: 'template_default',
  TaskSource.userAdded: 'user_added',
};

const _$TaskOwnerTypeEnumMap = {
  TaskOwnerType.organizer: 'organizer',
  TaskOwnerType.vendor: 'vendor',
  TaskOwnerType.planner: 'planner',
};

Task _$TaskFromJson(Map<String, dynamic> json) => Task(
  id: json['id'] as String,
  eventGroupId: json['eventGroupId'] as String,
  subEventId: json['subEventId'] as String?,
  taskCategoryId: json['taskCategoryId'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  status: $enumDecode(_$TaskStatusEnumMap, json['status']),
  dueDate: json['dueDate'] == null
      ? null
      : DateTime.parse(json['dueDate'] as String),
  source: $enumDecode(_$TaskSourceEnumMap, json['source']),
  ownerType: $enumDecode(_$TaskOwnerTypeEnumMap, json['ownerType']),
  ownerUserId: json['ownerUserId'] as String?,
  linkedVendorId: json['linkedVendorId'] as String?,
  linkedBudgetCategoryId: json['linkedBudgetCategoryId'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$TaskToJson(Task instance) => <String, dynamic>{
  'id': instance.id,
  'eventGroupId': instance.eventGroupId,
  'subEventId': instance.subEventId,
  'taskCategoryId': instance.taskCategoryId,
  'name': instance.name,
  'description': instance.description,
  'status': _$TaskStatusEnumMap[instance.status]!,
  'dueDate': instance.dueDate?.toIso8601String(),
  'source': _$TaskSourceEnumMap[instance.source]!,
  'ownerType': _$TaskOwnerTypeEnumMap[instance.ownerType]!,
  'ownerUserId': instance.ownerUserId,
  'linkedVendorId': instance.linkedVendorId,
  'linkedBudgetCategoryId': instance.linkedBudgetCategoryId,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};

ListEventGroupTasksResponse _$ListEventGroupTasksResponseFromJson(
  Map<String, dynamic> json,
) => ListEventGroupTasksResponse(
  tasks: (json['tasks'] as List<dynamic>)
      .map((e) => TaskWithDependencies.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ListEventGroupTasksResponseToJson(
  ListEventGroupTasksResponse instance,
) => <String, dynamic>{'tasks': instance.tasks.map((e) => e.toJson()).toList()};

GenerateRoadmapResponse _$GenerateRoadmapResponseFromJson(
  Map<String, dynamic> json,
) => GenerateRoadmapResponse(
  tasks: (json['tasks'] as List<dynamic>)
      .map((e) => TaskWithDependencies.fromJson(e as Map<String, dynamic>))
      .toList(),
  removedTaskCount: (json['removedTaskCount'] as num?)?.toInt(),
);

Map<String, dynamic> _$GenerateRoadmapResponseToJson(
  GenerateRoadmapResponse instance,
) => <String, dynamic>{
  'tasks': instance.tasks.map((e) => e.toJson()).toList(),
  'removedTaskCount': instance.removedTaskCount,
};

GenerateRoadmapBody _$GenerateRoadmapBodyFromJson(Map<String, dynamic> json) =>
    GenerateRoadmapBody(
      mode: $enumDecodeNullable(_$RoadmapRegenModeEnumMap, json['mode']),
    );

Map<String, dynamic> _$GenerateRoadmapBodyToJson(
  GenerateRoadmapBody instance,
) => <String, dynamic>{'mode': ?_$RoadmapRegenModeEnumMap[instance.mode]};

const _$RoadmapRegenModeEnumMap = {
  RoadmapRegenMode.keepMyWork: 'keep_my_work',
  RoadmapRegenMode.replaceAll: 'replace_all',
  RoadmapRegenMode.addMissing: 'add_missing',
};

CreateTaskBody _$CreateTaskBodyFromJson(Map<String, dynamic> json) =>
    CreateTaskBody(
      name: json['name'] as String,
      category: json['category'] as String,
      dueDate: json['dueDate'] as String,
      dependencyTaskIds: (json['dependencyTaskIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$CreateTaskBodyToJson(CreateTaskBody instance) =>
    <String, dynamic>{
      'name': instance.name,
      'category': instance.category,
      'dueDate': instance.dueDate,
      'dependencyTaskIds': ?instance.dependencyTaskIds,
    };

TaskCategory _$TaskCategoryFromJson(Map<String, dynamic> json) => TaskCategory(
  id: json['id'] as String,
  categoryKey: json['categoryKey'] as String,
);

Map<String, dynamic> _$TaskCategoryToJson(TaskCategory instance) =>
    <String, dynamic>{'id': instance.id, 'categoryKey': instance.categoryKey};

ListTaskCategoriesResponse _$ListTaskCategoriesResponseFromJson(
  Map<String, dynamic> json,
) => ListTaskCategoriesResponse(
  categories: (json['categories'] as List<dynamic>)
      .map((e) => TaskCategory.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ListTaskCategoriesResponseToJson(
  ListTaskCategoriesResponse instance,
) => <String, dynamic>{
  'categories': instance.categories.map((e) => e.toJson()).toList(),
};
