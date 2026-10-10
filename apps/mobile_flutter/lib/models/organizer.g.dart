// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organizer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Organizer _$OrganizerFromJson(Map<String, dynamic> json) => Organizer(
  id: json['id'] as String,
  phoneNumber: json['phoneNumber'] as String,
  email: json['email'] as String?,
  displayName: json['displayName'] as String?,
  organizerType: $enumDecodeNullable(
    _$OrganizerTypeEnumMap,
    json['organizerType'],
  ),
  preferredLanguage: json['preferredLanguage'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  status: $enumDecode(_$OrganizerStatusEnumMap, json['status']),
);

Map<String, dynamic> _$OrganizerToJson(Organizer instance) => <String, dynamic>{
  'id': instance.id,
  'phoneNumber': instance.phoneNumber,
  'email': instance.email,
  'displayName': instance.displayName,
  'organizerType': _$OrganizerTypeEnumMap[instance.organizerType],
  'preferredLanguage': instance.preferredLanguage,
  'createdAt': instance.createdAt.toIso8601String(),
  'status': _$OrganizerStatusEnumMap[instance.status]!,
};

const _$OrganizerTypeEnumMap = {
  OrganizerType.individual: 'individual',
  OrganizerType.family: 'family',
  OrganizerType.company: 'company',
  OrganizerType.committee: 'committee',
};

const _$OrganizerStatusEnumMap = {
  OrganizerStatus.active: 'active',
  OrganizerStatus.suspended: 'suspended',
};

UpdateOrganizerProfileBody _$UpdateOrganizerProfileBodyFromJson(
  Map<String, dynamic> json,
) => UpdateOrganizerProfileBody(
  displayName: json['displayName'] as String,
  organizerType: $enumDecode(_$OrganizerTypeEnumMap, json['organizerType']),
);

Map<String, dynamic> _$UpdateOrganizerProfileBodyToJson(
  UpdateOrganizerProfileBody instance,
) => <String, dynamic>{
  'displayName': instance.displayName,
  'organizerType': _$OrganizerTypeEnumMap[instance.organizerType]!,
};
