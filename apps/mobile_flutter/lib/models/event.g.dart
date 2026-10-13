// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubEvent _$SubEventFromJson(Map<String, dynamic> json) => SubEvent(
  id: json['id'] as String,
  eventGroupId: json['eventGroupId'] as String,
  name: json['name'] as String,
  subEventType: json['subEventType'] as String?,
  date: DateTime.parse(json['date'] as String),
  startTime: json['startTime'] as String?,
  endTime: json['endTime'] as String?,
  venueName: json['venueName'] as String?,
  venueAddress: json['venueAddress'] as String?,
  expectedGuestCount: (json['expectedGuestCount'] as num?)?.toInt(),
  status: $enumDecode(_$SubEventStatusEnumMap, json['status']),
);

Map<String, dynamic> _$SubEventToJson(SubEvent instance) => <String, dynamic>{
  'id': instance.id,
  'eventGroupId': instance.eventGroupId,
  'name': instance.name,
  'subEventType': instance.subEventType,
  'date': instance.date.toIso8601String(),
  'startTime': instance.startTime,
  'endTime': instance.endTime,
  'venueName': instance.venueName,
  'venueAddress': instance.venueAddress,
  'expectedGuestCount': instance.expectedGuestCount,
  'status': _$SubEventStatusEnumMap[instance.status]!,
};

const _$SubEventStatusEnumMap = {
  SubEventStatus.planned: 'planned',
  SubEventStatus.inProgress: 'in_progress',
  SubEventStatus.completed: 'completed',
  SubEventStatus.cancelled: 'cancelled',
};

BudgetCategory _$BudgetCategoryFromJson(Map<String, dynamic> json) =>
    BudgetCategory(
      id: json['id'] as String,
      eventGroupId: json['eventGroupId'] as String,
      categoryKey: json['categoryKey'] as String,
      allocatedAmount: const MoneyConverter().fromJson(json['allocatedAmount']),
      budgetTierOverride: $enumDecodeNullable(
        _$BudgetTierEnumMap,
        json['budgetTierOverride'],
      ),
    );

Map<String, dynamic> _$BudgetCategoryToJson(
  BudgetCategory instance,
) => <String, dynamic>{
  'id': instance.id,
  'eventGroupId': instance.eventGroupId,
  'categoryKey': instance.categoryKey,
  'allocatedAmount': const MoneyConverter().toJson(instance.allocatedAmount),
  'budgetTierOverride': _$BudgetTierEnumMap[instance.budgetTierOverride],
};

const _$BudgetTierEnumMap = {
  BudgetTier.essential: 'essential',
  BudgetTier.standard: 'standard',
  BudgetTier.premium: 'premium',
  BudgetTier.luxury: 'luxury',
};

EventGroup _$EventGroupFromJson(Map<String, dynamic> json) => EventGroup(
  id: json['id'] as String,
  organizerId: json['organizerId'] as String,
  eventType: $enumDecode(_$EventTypeEnumMap, json['eventType']),
  name: json['name'] as String,
  region: json['region'] as String,
  religionOrTradition: json['religionOrTradition'] as String?,
  totalBudget: const MoneyConverter().fromJson(json['totalBudget']),
  budgetTier: $enumDecode(_$BudgetTierEnumMap, json['budgetTier']),
  guestCountEstimate: (json['guestCountEstimate'] as num).toInt(),
  primaryDate: DateTime.parse(json['primaryDate'] as String),
  status: $enumDecode(_$EventGroupStatusEnumMap, json['status']),
  createdAt: DateTime.parse(json['createdAt'] as String),
  subEvents:
      (json['subEvents'] as List<dynamic>?)
          ?.map((e) => SubEvent.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  budgetCategories:
      (json['budgetCategories'] as List<dynamic>?)
          ?.map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
  tasks:
      (json['tasks'] as List<dynamic>?)
          ?.map((e) => TaskWithDependencies.fromJson(e as Map<String, dynamic>))
          .toList() ??
      [],
);

Map<String, dynamic> _$EventGroupToJson(
  EventGroup instance,
) => <String, dynamic>{
  'id': instance.id,
  'organizerId': instance.organizerId,
  'eventType': _$EventTypeEnumMap[instance.eventType]!,
  'name': instance.name,
  'region': instance.region,
  'religionOrTradition': instance.religionOrTradition,
  'totalBudget': const MoneyConverter().toJson(instance.totalBudget),
  'budgetTier': _$BudgetTierEnumMap[instance.budgetTier]!,
  'guestCountEstimate': instance.guestCountEstimate,
  'primaryDate': instance.primaryDate.toIso8601String(),
  'status': _$EventGroupStatusEnumMap[instance.status]!,
  'createdAt': instance.createdAt.toIso8601String(),
  'subEvents': instance.subEvents.map((e) => e.toJson()).toList(),
  'budgetCategories': instance.budgetCategories.map((e) => e.toJson()).toList(),
  'tasks': instance.tasks.map((e) => e.toJson()).toList(),
};

const _$EventTypeEnumMap = {
  EventType.wedding: 'wedding',
  EventType.birthday: 'birthday',
  EventType.corporate: 'corporate',
  EventType.religious: 'religious',
  EventType.engagementOnly: 'engagement_only',
  EventType.custom: 'custom',
};

const _$EventGroupStatusEnumMap = {
  EventGroupStatus.planning: 'planning',
  EventGroupStatus.active: 'active',
  EventGroupStatus.completed: 'completed',
  EventGroupStatus.archived: 'archived',
};

CreateEventGroupBody _$CreateEventGroupBodyFromJson(
  Map<String, dynamic> json,
) => CreateEventGroupBody(
  eventType: $enumDecode(_$EventTypeEnumMap, json['eventType']),
  name: json['name'] as String,
  region: json['region'] as String,
  religionOrTradition: json['religionOrTradition'] as String?,
  details: json['details'] as Map<String, dynamic>?,
  generatedProfileId: json['generatedProfileId'] as String?,
  totalBudget: (json['totalBudget'] as num).toDouble(),
  budgetTier: $enumDecode(_$BudgetTierEnumMap, json['budgetTier']),
  guestCountEstimate: (json['guestCountEstimate'] as num).toInt(),
  primaryDate: json['primaryDate'] as String,
);

Map<String, dynamic> _$CreateEventGroupBodyToJson(
  CreateEventGroupBody instance,
) => <String, dynamic>{
  'eventType': _$EventTypeEnumMap[instance.eventType]!,
  'name': instance.name,
  'region': instance.region,
  'religionOrTradition': ?instance.religionOrTradition,
  'details': ?instance.details,
  'generatedProfileId': ?instance.generatedProfileId,
  'totalBudget': instance.totalBudget,
  'budgetTier': _$BudgetTierEnumMap[instance.budgetTier]!,
  'guestCountEstimate': instance.guestCountEstimate,
  'primaryDate': instance.primaryDate,
};

UpdateEventGroupBody _$UpdateEventGroupBodyFromJson(
  Map<String, dynamic> json,
) => UpdateEventGroupBody(
  name: json['name'] as String?,
  totalBudget: (json['totalBudget'] as num?)?.toDouble(),
  budgetTier: $enumDecodeNullable(_$BudgetTierEnumMap, json['budgetTier']),
  guestCountEstimate: (json['guestCountEstimate'] as num?)?.toInt(),
  primaryDate: json['primaryDate'] as String?,
  budgetAdjustment: $enumDecodeNullable(
    _$BudgetAdjustmentEnumMap,
    json['budgetAdjustment'],
  ),
);

Map<String, dynamic> _$UpdateEventGroupBodyToJson(
  UpdateEventGroupBody instance,
) => <String, dynamic>{
  'name': ?instance.name,
  'totalBudget': ?instance.totalBudget,
  'budgetTier': ?_$BudgetTierEnumMap[instance.budgetTier],
  'guestCountEstimate': ?instance.guestCountEstimate,
  'primaryDate': ?instance.primaryDate,
  'budgetAdjustment': ?_$BudgetAdjustmentEnumMap[instance.budgetAdjustment],
};

const _$BudgetAdjustmentEnumMap = {
  BudgetAdjustment.rescale: 'rescale',
  BudgetAdjustment.keep: 'keep',
};

UpdateEventGroupResponse _$UpdateEventGroupResponseFromJson(
  Map<String, dynamic> json,
) => UpdateEventGroupResponse(
  eventGroup: EventGroup.fromJson(json['eventGroup'] as Map<String, dynamic>),
  budgetCategories: (json['budgetCategories'] as List<dynamic>)
      .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
      .toList(),
  warning: json['warning'] as String?,
);

Map<String, dynamic> _$UpdateEventGroupResponseToJson(
  UpdateEventGroupResponse instance,
) => <String, dynamic>{
  'eventGroup': instance.eventGroup.toJson(),
  'budgetCategories': instance.budgetCategories.map((e) => e.toJson()).toList(),
  'warning': instance.warning,
};

CreateBudgetCategoryBody _$CreateBudgetCategoryBodyFromJson(
  Map<String, dynamic> json,
) => CreateBudgetCategoryBody(
  categoryKey: json['categoryKey'] as String,
  allocatedAmount: (json['allocatedAmount'] as num).toDouble(),
);

Map<String, dynamic> _$CreateBudgetCategoryBodyToJson(
  CreateBudgetCategoryBody instance,
) => <String, dynamic>{
  'categoryKey': instance.categoryKey,
  'allocatedAmount': instance.allocatedAmount,
};

UpdateBudgetCategoryBody _$UpdateBudgetCategoryBodyFromJson(
  Map<String, dynamic> json,
) => UpdateBudgetCategoryBody(
  allocatedAmount: (json['allocatedAmount'] as num?)?.toDouble(),
  budgetTierOverride: $enumDecodeNullable(
    _$BudgetTierEnumMap,
    json['budgetTierOverride'],
  ),
  categoryKey: json['categoryKey'] as String?,
);

Map<String, dynamic> _$UpdateBudgetCategoryBodyToJson(
  UpdateBudgetCategoryBody instance,
) => <String, dynamic>{
  'allocatedAmount': ?instance.allocatedAmount,
  'budgetTierOverride': ?_$BudgetTierEnumMap[instance.budgetTierOverride],
  'categoryKey': ?instance.categoryKey,
};

BudgetCategoryMutationResponse _$BudgetCategoryMutationResponseFromJson(
  Map<String, dynamic> json,
) => BudgetCategoryMutationResponse(
  budgetCategory: BudgetCategory.fromJson(
    json['budgetCategory'] as Map<String, dynamic>,
  ),
  warning: json['warning'] as String?,
);

Map<String, dynamic> _$BudgetCategoryMutationResponseToJson(
  BudgetCategoryMutationResponse instance,
) => <String, dynamic>{
  'budgetCategory': instance.budgetCategory.toJson(),
  'warning': instance.warning,
};

DeleteBudgetCategoryResponse _$DeleteBudgetCategoryResponseFromJson(
  Map<String, dynamic> json,
) => DeleteBudgetCategoryResponse(
  budgetCategories: (json['budgetCategories'] as List<dynamic>)
      .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
      .toList(),
  warning: json['warning'] as String?,
);

Map<String, dynamic> _$DeleteBudgetCategoryResponseToJson(
  DeleteBudgetCategoryResponse instance,
) => <String, dynamic>{
  'budgetCategories': instance.budgetCategories.map((e) => e.toJson()).toList(),
  'warning': instance.warning,
};

DeleteEventGroupResponse _$DeleteEventGroupResponseFromJson(
  Map<String, dynamic> json,
) => DeleteEventGroupResponse(
  deleted: json['deleted'] as bool,
  id: json['id'] as String,
);

Map<String, dynamic> _$DeleteEventGroupResponseToJson(
  DeleteEventGroupResponse instance,
) => <String, dynamic>{'deleted': instance.deleted, 'id': instance.id};
