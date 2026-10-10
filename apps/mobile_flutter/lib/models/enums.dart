// Dart mirrors of the enums in apps/backend/prisma/schema.prisma (see
// packages/shared-types/src/enums.ts). Wire values are the snake_case strings.
// Only enums the app touches are ported; schema-only ones (bookings, payments,
// notifications, ...) are left out until their features exist.
import 'package:json_annotation/json_annotation.dart';

@JsonEnum(fieldRename: FieldRename.snake)
enum AuthRole { organizer, vendor, admin }

@JsonEnum(fieldRename: FieldRename.snake)
enum AdminRole { superAdmin, vendorReviewer, support }

@JsonEnum(fieldRename: FieldRename.snake)
enum OrganizerType { individual, family, company, committee }

@JsonEnum(fieldRename: FieldRename.snake)
enum OrganizerStatus { active, suspended }

@JsonEnum(fieldRename: FieldRename.snake)
enum VendorPriceTier { essential, standard, premium, luxury }

@JsonEnum(fieldRename: FieldRename.snake)
enum VendorStatus { draft, pendingReview, published, rejected, suspended }

@JsonEnum(fieldRename: FieldRename.snake)
enum EventType { wedding, birthday, corporate, religious, engagementOnly, custom }

@JsonEnum(fieldRename: FieldRename.snake)
enum BudgetTier { essential, standard, premium, luxury }

@JsonEnum(fieldRename: FieldRename.snake)
enum EventGroupStatus { planning, active, completed, archived }

@JsonEnum(fieldRename: FieldRename.snake)
enum SubEventStatus { planned, inProgress, completed, cancelled }

@JsonEnum(fieldRename: FieldRename.snake)
enum TaskOwnerType { organizer, vendor, planner }

@JsonEnum(fieldRename: FieldRename.snake)
enum TaskStatus { notStarted, inProgress, done, overdue, notApplicable }

@JsonEnum(fieldRename: FieldRename.snake)
enum TaskSource { aiGenerated, templateDefault, userAdded }

@JsonEnum(fieldRename: FieldRename.snake)
enum RoadmapRegenMode { keepMyWork, replaceAll, addMissing }

@JsonEnum(fieldRename: FieldRename.snake)
enum BudgetAdjustment { rescale, keep }

/// Wire value (snake_case) of any enum generated with FieldRename.snake.
String enumWireValue(Enum e) => e.name.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => '_${m[0]!.toLowerCase()}',
    );
