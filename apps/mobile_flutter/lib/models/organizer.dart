import 'package:json_annotation/json_annotation.dart';

import 'enums.dart';

part 'organizer.g.dart';

@JsonSerializable()
class Organizer {
  const Organizer({
    required this.id,
    required this.phoneNumber,
    this.email,
    this.displayName,
    this.organizerType,
    this.preferredLanguage,
    required this.createdAt,
    required this.status,
  });
  factory Organizer.fromJson(Map<String, dynamic> json) => _$OrganizerFromJson(json);
  final String id;
  final String phoneNumber;
  final String? email;
  final String? displayName;
  final OrganizerType? organizerType;
  final String? preferredLanguage;
  final DateTime createdAt;
  final OrganizerStatus status;
  Map<String, dynamic> toJson() => _$OrganizerToJson(this);
}

@JsonSerializable()
class UpdateOrganizerProfileBody {
  const UpdateOrganizerProfileBody({required this.displayName, required this.organizerType});
  factory UpdateOrganizerProfileBody.fromJson(Map<String, dynamic> json) =>
      _$UpdateOrganizerProfileBodyFromJson(json);
  final String displayName;
  final OrganizerType organizerType;
  Map<String, dynamic> toJson() => _$UpdateOrganizerProfileBodyToJson(this);
}
