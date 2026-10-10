import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/models/auth.dart';
import 'package:sanchalan/models/converters.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/event.dart';
import 'package:sanchalan/models/organizer.dart';
import 'package:sanchalan/models/roadmap.dart';
import 'package:sanchalan/models/vendor.dart';
import 'package:sanchalan/models/vendor_labels.dart';

// Shapes mirror what apps/backend actually sends (see the services'
// serialize* helpers): money as numbers on events, Prisma Decimals as strings
// on vendors, date-only strings for primaryDate / sub-event date / dueDate.

Map<String, dynamic> roundTrip(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

final taskJson = {
  'id': 't1',
  'eventGroupId': 'e1',
  'subEventId': null,
  'taskCategoryId': 'c1',
  'name': 'Book venue',
  'description': null,
  'status': 'not_started',
  'dueDate': '2026-11-01',
  'source': 'ai_generated',
  'ownerType': 'organizer',
  'ownerUserId': null,
  'linkedVendorId': null,
  'linkedBudgetCategoryId': null,
  'createdAt': '2026-10-01T10:00:00.000Z',
  'updatedAt': '2026-10-01T10:00:00.000Z',
  'categoryKey': 'venue',
  'dependsOnTaskIds': ['t0'],
};

final vendorJson = {
  'id': 'v1',
  'businessName': 'Shubh Photos',
  'contactPersonName': 'Asha',
  'phoneNumber': '+919999999999',
  'email': null,
  'priceTier': 'premium',
  'serviceArea': 'Pune',
  'description': 'Candid wedding photography',
  'yearsOfExperience': 7,
  'startingPrice': '50000', // Prisma Decimal -> string
  'instagramUrl': null,
  'websiteUrl': null,
  'whatsappNumber': null,
  'status': 'pending_review',
  'rejectionReason': null,
  'submittedAt': '2026-10-02T09:00:00.000Z',
  'reviewedAt': null,
  'reviewedBy': null,
  'createdAt': '2026-10-01T09:00:00.000Z',
  'vendorVendorCategories': [
    {
      'vendorId': 'v1',
      'vendorCategoryId': 'vc1',
      'vendorCategory': {
        'id': 'vc1',
        'categoryKey': 'photography',
        'applicableEventTypes': ['wedding', 'engagement_only'],
      },
    },
  ],
  'portfolioItems': [
    {
      'id': 'p1',
      'vendorId': 'v1',
      'title': 'Sharma wedding',
      'mediaUrl': null,
      'caption': 'Pune, 2025',
      'displayOrder': 0,
      'createdAt': '2026-10-01T09:30:00.000Z',
    },
  ],
};

final eventGroupJson = {
  'id': 'e1',
  'organizerId': 'o1',
  'eventType': 'wedding',
  'name': 'Priya & Rohan',
  'region': 'Pune',
  'religionOrTradition': null,
  'totalBudget': 1500000,
  'budgetTier': 'standard',
  'guestCountEstimate': 250,
  'primaryDate': '2027-02-14',
  'status': 'planning',
  'createdAt': '2026-10-01T08:00:00.000Z',
  'subEvents': [
    {
      'id': 's1',
      'eventGroupId': 'e1',
      'name': 'Wedding',
      'subEventType': null,
      'date': '2027-02-14',
      'startTime': null,
      'endTime': null,
      'venueName': null,
      'venueAddress': null,
      'expectedGuestCount': 250,
      'status': 'planned',
    },
  ],
};

void main() {
  group('auth', () {
    test('AuthTokens parses with and without adminRole', () {
      final organizer = AuthTokens.fromJson({
        'accessToken': 'a',
        'refreshToken': 'r',
        'role': 'organizer',
        'userId': 'u1',
      });
      expect(organizer.role, AuthRole.organizer);
      expect(organizer.adminRole, isNull);
      expect(organizer.toJson().containsKey('adminRole'), isFalse);

      final admin = AuthTokens.fromJson({
        'accessToken': 'a',
        'refreshToken': 'r',
        'role': 'admin',
        'userId': 'u2',
        'adminRole': 'vendor_reviewer',
      });
      expect(admin.adminRole, AdminRole.vendorReviewer);
    });

    test('request bodies serialize snake_case enums', () {
      expect(
        const OtpRequestBody(phoneNumber: '+919999999999', role: AuthRole.vendor).toJson(),
        {'phoneNumber': '+919999999999', 'role': 'vendor'},
      );
      expect(
        const OtpVerifyBody(phoneNumber: '+91', otp: '123456', role: AuthRole.organizer).toJson(),
        {'phoneNumber': '+91', 'otp': '123456', 'role': 'organizer'},
      );
    });

    test('OtpRequestResponse and RefreshResponse', () {
      expect(OtpRequestResponse.fromJson({'expiresInSeconds': 300}).expiresInSeconds, 300);
      expect(RefreshResponse.fromJson({'accessToken': 'x'}).accessToken, 'x');
    });
  });

  group('organizer', () {
    test('parses a fresh organizer with null profile fields', () {
      final o = Organizer.fromJson({
        'id': 'o1',
        'phoneNumber': '+919999999999',
        'email': null,
        'displayName': null,
        'organizerType': null,
        'preferredLanguage': null,
        'createdAt': '2026-10-01T08:00:00.000Z',
        'status': 'active',
      });
      expect(o.displayName, isNull);
      expect(o.organizerType, isNull);
      expect(o.status, OrganizerStatus.active);
    });

    test('profile body', () {
      expect(
        const UpdateOrganizerProfileBody(
          displayName: 'Priya',
          organizerType: OrganizerType.family,
        ).toJson(),
        {'displayName': 'Priya', 'organizerType': 'family'},
      );
    });
  });

  group('events', () {
    test('list item has no budget categories or tasks', () {
      final eg = EventGroup.fromJson(eventGroupJson);
      expect(eg.totalBudget, 1500000);
      expect(eg.primaryDate, DateTime(2027, 2, 14));
      expect(eg.subEvents.single.status, SubEventStatus.planned);
      expect(eg.budgetCategories, isEmpty);
      expect(eg.tasks, isEmpty);
    });

    test('detail includes budget categories and tasks; money may be a string', () {
      final json = {
        ...eventGroupJson,
        'totalBudget': '1500000.50',
        'budgetCategories': [
          {
            'id': 'b1',
            'eventGroupId': 'e1',
            'categoryKey': 'catering',
            'allocatedAmount': 400000,
            'budgetTierOverride': null,
          },
        ],
        'tasks': [taskJson],
      };
      final eg = EventGroup.fromJson(json);
      expect(eg.totalBudget, 1500000.5);
      expect(eg.budgetCategories.single.allocatedAmount, 400000);
      expect(eg.tasks.single.categoryKey, 'venue');
      // Survives a full encode/decode cycle.
      final again = EventGroup.fromJson(roundTrip(eg.toJson()));
      expect(again.tasks.single.dependsOnTaskIds, ['t0']);
      expect(again.subEvents.single.name, 'Wedding');
    });

    test('update response and budget mutation responses', () {
      final update = UpdateEventGroupResponse.fromJson({
        'eventGroup': eventGroupJson,
        'budgetCategories': <Object>[],
        'warning': 'Allocated budget exceeds total budget',
      });
      expect(update.warning, isNotNull);

      final created = BudgetCategoryMutationResponse.fromJson({
        'budgetCategory': {
          'id': 'b1',
          'eventGroupId': 'e1',
          'categoryKey': 'decor',
          'allocatedAmount': 1000,
          'budgetTierOverride': 'luxury',
        },
        'warning': null,
      });
      expect(created.budgetCategory.budgetTierOverride, BudgetTier.luxury);
      expect(created.warning, isNull);

      expect(DeleteBudgetCategoryResponse.fromJson({'budgetCategories': <Object>[], 'warning': null})
          .budgetCategories, isEmpty);
      expect(DeleteEventGroupResponse.fromJson({'deleted': true, 'id': 'e1'}).deleted, isTrue);
    });

    test('request bodies drop nulls and use wire values', () {
      expect(
        const CreateEventGroupBody(
          eventType: EventType.engagementOnly,
          name: 'N',
          region: 'Pune',
          totalBudget: 100000,
          budgetTier: BudgetTier.essential,
          guestCountEstimate: 50,
          primaryDate: '2027-02-14',
        ).toJson(),
        {
          'eventType': 'engagement_only',
          'name': 'N',
          'region': 'Pune',
          'totalBudget': 100000.0,
          'budgetTier': 'essential',
          'guestCountEstimate': 50,
          'primaryDate': '2027-02-14',
        },
      );
      expect(
        const UpdateEventGroupBody(totalBudget: 5, budgetAdjustment: BudgetAdjustment.rescale)
            .toJson(),
        {'totalBudget': 5.0, 'budgetAdjustment': 'rescale'},
      );
      expect(
        const UpdateBudgetCategoryBody(budgetTierOverride: BudgetTier.premium).toJson(),
        {'budgetTierOverride': 'premium'},
      );
      expect(const CreateBudgetCategoryBody(categoryKey: 'misc', allocatedAmount: 10).toJson(),
          {'categoryKey': 'misc', 'allocatedAmount': 10.0});
    });
  });

  group('roadmap', () {
    test('every task status / source / owner wire value parses', () {
      for (final status in ['not_started', 'in_progress', 'done', 'overdue', 'not_applicable']) {
        for (final source in ['ai_generated', 'template_default', 'user_added']) {
          for (final owner in ['organizer', 'vendor', 'planner']) {
            final t = TaskWithDependencies.fromJson(
              {...taskJson, 'status': status, 'source': source, 'ownerType': owner},
            );
            expect(enumWireValue(t.status), status);
            expect(enumWireValue(t.source), source);
            expect(enumWireValue(t.ownerType), owner);
          }
        }
      }
    });

    test('undated task and missing dependent ids', () {
      final t = TaskWithDependencies.fromJson({...taskJson, 'dueDate': null});
      expect(t.dueDate, isNull);
      expect(t.dependentTaskIds, isEmpty);
    });

    test('plain Task (PATCH /tasks/:id response)', () {
      final json = Map<String, dynamic>.of(taskJson)
        ..remove('categoryKey')
        ..remove('dependsOnTaskIds');
      expect(Task.fromJson(json).name, 'Book venue');
    });

    test('responses', () {
      expect(GenerateRoadmapResponse.fromJson({'tasks': [taskJson], 'removedTaskCount': 3})
          .removedTaskCount, 3);
      expect(GenerateRoadmapResponse.fromJson({'tasks': [taskJson]}).removedTaskCount, isNull);
      expect(ListEventGroupTasksResponse.fromJson({'tasks': [taskJson]}).tasks, hasLength(1));
      expect(ListTaskCategoriesResponse.fromJson({
        'categories': [
          {'id': 'c1', 'categoryKey': 'venue'},
        ],
      }).categories.single.categoryKey, 'venue');
    });

    test('request bodies', () {
      expect(const GenerateRoadmapBody().toJson(), <String, dynamic>{});
      expect(const GenerateRoadmapBody(mode: RoadmapRegenMode.keepMyWork).toJson(),
          {'mode': 'keep_my_work'});
      expect(
        const CreateTaskBody(name: 'x', category: 'venue', dueDate: '2027-01-01').toJson(),
        {'name': 'x', 'category': 'venue', 'dueDate': '2027-01-01'},
      );
    });

    test('UpdateTaskBody sends explicit nulls only when asked', () {
      expect(const UpdateTaskBody(status: TaskStatus.inProgress).toJson(), {'status': 'in_progress'});
      expect(const UpdateTaskBody(clearDueDate: true).toJson(), {'dueDate': null});
      expect(const UpdateTaskBody(dueDate: '2027-01-01', name: 'n').toJson(),
          {'dueDate': '2027-01-01', 'name': 'n'});
      expect(const UpdateTaskBody().toJson(), <String, dynamic>{});
    });
  });

  group('vendor', () {
    test('parses Decimal-as-string startingPrice, categories and past work', () {
      final v = Vendor.fromJson(vendorJson);
      expect(v.startingPrice, 50000);
      expect(v.status, VendorStatus.pendingReview);
      expect(v.priceTier, VendorPriceTier.premium);
      expect(v.categoryKeys, ['photography']);
      expect(v.vendorVendorCategories.single.vendorCategory.applicableEventTypes,
          [EventType.wedding, EventType.engagementOnly]);
      expect(v.portfolioItems.single.title, 'Sharma wedding');
      expect(Vendor.fromJson(roundTrip(v.toJson())).startingPrice, 50000);
    });

    test('draft vendor with nulls and no relations', () {
      final v = Vendor.fromJson({
        'id': 'v2',
        'phoneNumber': '+91',
        'status': 'draft',
        'createdAt': '2026-10-01T09:00:00.000Z',
      });
      expect(v.businessName, isNull);
      expect(v.startingPrice, isNull);
      expect(v.portfolioItems, isEmpty);
    });

    test('startingPrice as number also works', () {
      expect(Vendor.fromJson({...vendorJson, 'startingPrice': 1200.5}).startingPrice, 1200.5);
    });

    test('every vendor status parses', () {
      for (final s in ['draft', 'pending_review', 'published', 'rejected', 'suspended']) {
        expect(enumWireValue(Vendor.fromJson({...vendorJson, 'status': s}).status), s);
      }
    });

    test('VendorMeResponse reads completeness next to the vendor fields', () {
      final me = VendorMeResponse.fromJson({
        ...vendorJson,
        'completeness': {
          'complete': false,
          'missing': ['pastWork', 'categories'],
        },
      });
      expect(me.vendor.businessName, 'Shubh Photos');
      expect(me.completeness.complete, isFalse);
      expect(me.completeness.missing, [VendorRequiredField.pastWork, VendorRequiredField.categories]);
      final again = VendorMeResponse.fromJson(roundTrip(me.toJson()));
      expect(again.completeness.missing, hasLength(2));
    });

    test('UpdateVendorProfileResponse', () {
      final r = UpdateVendorProfileResponse.fromJson({
        'vendor': {
          ...vendorJson,
          'completeness': {'complete': true, 'missing': <Object>[]},
        },
        'reverificationTriggered': true,
      });
      expect(r.reverificationTriggered, isTrue);
      expect(r.vendor.completeness.complete, isTrue);
    });

    test('lists and bodies', () {
      expect(ListVendorsResponse.fromJson({'vendors': [vendorJson]}).vendors, hasLength(1));
      expect(ListVendorCategoriesResponse.fromJson({
        'categories': [
          {'id': 'vc1', 'categoryKey': 'venue'},
        ],
      }).categories.single.applicableEventTypes, isEmpty);
      expect(const UpdateVendorProfileBody(priceTier: VendorPriceTier.luxury, startingPrice: 9)
          .toJson(), {'priceTier': 'luxury', 'startingPrice': 9.0});
      expect(const SetVendorCategoriesBody(categoryKeys: ['venue']).toJson(),
          {'categoryKeys': ['venue']});
      expect(const PastWorkBody(title: 't').toJson(), {'title': 't', 'caption': null});
      expect(const ReorderPastWorkBody(itemIds: ['a', 'b']).toJson(), {'itemIds': ['a', 'b']});
    });

    test('labels', () {
      expect(vendorCategoryLabel('music_entertainment'), 'Music & Entertainment');
      expect(vendorCategoryLabel('light_and_sound'), 'Light and sound');
      expect(vendorPriceTierLabels[VendorPriceTier.luxury], 'Luxury');
    });
  });

  group('helpers', () {
    test('enumWireValue covers camelCase -> snake_case', () {
      expect(enumWireValue(VendorStatus.pendingReview), 'pending_review');
      expect(enumWireValue(RoadmapRegenMode.keepMyWork), 'keep_my_work');
      expect(enumWireValue(AdminRole.superAdmin), 'super_admin');
    });

    test('toDateOnly pads', () {
      expect(toDateOnly(DateTime(2027, 2, 4)), '2027-02-04');
    });

    test('money converters', () {
      expect(const MoneyConverter().fromJson('12.5'), 12.5);
      expect(const MoneyConverter().fromJson(7), 7.0);
      expect(const NullableMoneyConverter().fromJson(null), isNull);
    });
  });
}
