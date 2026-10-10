import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/features/auth/auth_repository.dart';
import 'package:sanchalan/features/organizer/organizer_repository.dart';
import 'package:sanchalan/features/vendor/vendor_repository.dart';
import 'package:sanchalan/models/enums.dart';
import 'package:sanchalan/models/event.dart';
import 'package:sanchalan/models/organizer.dart';
import 'package:sanchalan/models/roadmap.dart';
import 'package:sanchalan/models/vendor.dart';

import '../helpers/fake_adapter.dart';

/// Dio wired to an adapter that answers every request with [response].
(Dio, FakeAdapter) dioReturning(Object? response) {
  final adapter = FakeAdapter((_) async => jsonBody(response));
  return (Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter, adapter);
}

void main() {
  group('AuthRepository', () {
    test('requestOtp', () async {
      final (dio, a) = dioReturning({'expiresInSeconds': 300});
      final r = await AuthRepository(dio).requestOtp('+919999999999', AuthRole.vendor);
      expect(r.expiresInSeconds, 300);
      final req = a.requests.single;
      expect([req.method, req.path], ['POST', '/auth/otp/request']);
      expect(req.data, {'phoneNumber': '+919999999999', 'role': 'vendor'});
    });

    test('verifyOtp', () async {
      final (dio, a) = dioReturning(fixture('auth_verify_organizer'));
      final t = await AuthRepository(dio)
          .verifyOtp(phoneNumber: '+91', otp: '123456', role: AuthRole.organizer);
      expect(t.role, AuthRole.organizer);
      expect(a.requests.single.data, {'phoneNumber': '+91', 'otp': '123456', 'role': 'organizer'});
      expect(a.requests.single.path, '/auth/otp/verify');
    });

    test('refresh and logout', () async {
      final (dio, a) = dioReturning({'accessToken': 'new'});
      final repo = AuthRepository(dio);
      expect(await repo.refresh('r1'), 'new');
      await repo.logout('r1');
      expect(a.requests.map((r) => r.path), ['/auth/refresh', '/auth/logout']);
      expect(a.requests.every((r) => r.data['refreshToken'] == 'r1'), isTrue);
    });
  });

  group('OrganizerRepository', () {
    test('profile', () async {
      final (dio, a) = dioReturning(fixture('organizer_profile'));
      final repo = OrganizerRepository(dio);
      await repo.getMe();
      await repo.updateProfile(const UpdateOrganizerProfileBody(
        displayName: 'Priya Sharma',
        organizerType: OrganizerType.family,
      ));
      expect([a.requests[0].method, a.requests[0].path], ['GET', '/organizers/me']);
      expect([a.requests[1].method, a.requests[1].path], ['POST', '/organizers/me/profile']);
      expect(a.requests[1].data, {'displayName': 'Priya Sharma', 'organizerType': 'family'});
    });

    test('events', () async {
      final (dio, a) = dioReturning(fixture('event_groups_me'));
      final repo = OrganizerRepository(dio);
      expect(await repo.listEventGroups(), isNotEmpty);
      expect([a.requests.single.method, a.requests.single.path], ['GET', '/event-groups/me']);

      final (dio2, a2) = dioReturning(fixture('event_group_detail'));
      expect((await OrganizerRepository(dio2).getEventGroup('e1')).tasks, isNotEmpty);
      expect(a2.requests.single.path, '/event-groups/e1');
    });

    test('createEventGroup posts the body with the long LLM timeout', () async {
      final (dio, a) = dioReturning(fixture('event_group_create'));
      await OrganizerRepository(dio).createEventGroup(const CreateEventGroupBody(
        eventType: EventType.wedding,
        name: 'Priya & Rohan',
        region: 'Pune',
        totalBudget: 1500000,
        budgetTier: BudgetTier.standard,
        guestCountEstimate: 250,
        primaryDate: '2027-02-14',
      ));
      final req = a.requests.single;
      expect([req.method, req.path], ['POST', '/event-groups']);
      expect(req.receiveTimeout, const Duration(seconds: 90));
      expect(req.data['primaryDate'], '2027-02-14');
      expect(req.data['eventType'], 'wedding');
    });

    test('updateEventGroup patches and parses the warning', () async {
      final (dio, a) = dioReturning(fixture('event_group_update'));
      final r = await OrganizerRepository(dio).updateEventGroup(
        'e1',
        const UpdateEventGroupBody(totalBudget: 1800000, budgetAdjustment: BudgetAdjustment.rescale),
      );
      expect(r.eventGroup.totalBudget, 1800000);
      expect([a.requests.single.method, a.requests.single.path], ['PATCH', '/event-groups/e1']);
      expect(a.requests.single.data, {'totalBudget': 1800000.0, 'budgetAdjustment': 'rescale'});
    });

    test('deleteEventGroup', () async {
      final (dio, a) = dioReturning({'deleted': true, 'id': 'e1'});
      await OrganizerRepository(dio).deleteEventGroup('e1');
      expect([a.requests.single.method, a.requests.single.path], ['DELETE', '/event-groups/e1']);
    });

    test('generateRoadmap sends mode only on a re-run, with the long timeout', () async {
      final (dio, a) = dioReturning(fixture('roadmap_generate'));
      final repo = OrganizerRepository(dio);
      await repo.generateRoadmap('e1');
      await repo.generateRoadmap('e1', mode: RoadmapRegenMode.keepMyWork);
      expect(a.requests.map((r) => r.path), everyElement('/event-groups/e1/generate-roadmap'));
      expect(a.requests[0].data, <String, dynamic>{});
      expect(a.requests[1].data, {'mode': 'keep_my_work'});
      expect(a.requests.every((r) => r.receiveTimeout == const Duration(seconds: 90)), isTrue);
    });

    test('tasks', () async {
      final (dio, a) = dioReturning(fixture('event_group_tasks'));
      final repo = OrganizerRepository(dio);
      await repo.listTasks('e1');
      await repo.listTasks('e1', includeNotApplicable: true);
      expect(a.requests[0].queryParameters, isEmpty);
      expect(a.requests[1].queryParameters, {'includeNotApplicable': true});

      final (dio2, a2) = dioReturning(fixture('task_create'));
      await OrganizerRepository(dio2).createTask(
        'e1',
        const CreateTaskBody(name: 'Buy gifts', category: 'venue', dueDate: '2027-01-20'),
      );
      expect([a2.requests.single.method, a2.requests.single.path], ['POST', '/event-groups/e1/tasks']);
      expect(a2.requests.single.data, {'name': 'Buy gifts', 'category': 'venue', 'dueDate': '2027-01-20'});

      final (dio3, a3) = dioReturning(fixture('task_update'));
      final repo3 = OrganizerRepository(dio3);
      await repo3.updateTask('t1', const UpdateTaskBody(status: TaskStatus.inProgress));
      await repo3.deleteTask('t1');
      expect([a3.requests[0].method, a3.requests[0].path], ['PATCH', '/tasks/t1']);
      expect(a3.requests[0].data, {'status': 'in_progress'});
      expect([a3.requests[1].method, a3.requests[1].path], ['DELETE', '/tasks/t1']);
    });

    test('task categories', () async {
      final (dio, a) = dioReturning(fixture('task_categories'));
      expect(await OrganizerRepository(dio).listTaskCategories(), isNotEmpty);
      expect(a.requests.single.path, '/task-categories');
    });

    test('budget categories', () async {
      final (dio, a) = dioReturning(fixture('budget_category_create'));
      final repo = OrganizerRepository(dio);
      await repo.createBudgetCategory('e1', const CreateBudgetCategoryBody(categoryKey: 'gifts', allocatedAmount: 50000));
      await repo.updateBudgetCategory(
        'e1',
        'b1',
        const UpdateBudgetCategoryBody(allocatedAmount: 90000, budgetTierOverride: BudgetTier.premium),
      );
      expect([a.requests[0].method, a.requests[0].path], ['POST', '/event-groups/e1/budget-categories']);
      expect(a.requests[0].data, {'categoryKey': 'gifts', 'allocatedAmount': 50000.0});
      expect([a.requests[1].method, a.requests[1].path],
          ['PATCH', '/event-groups/e1/budget-categories/b1']);
      expect(a.requests[1].data, {'allocatedAmount': 90000.0, 'budgetTierOverride': 'premium'});

      final (dio2, a2) = dioReturning(fixture('budget_category_delete'));
      final r = await OrganizerRepository(dio2).deleteBudgetCategory('e1', 'b1');
      expect(r.budgetCategories, isNotEmpty);
      expect([a2.requests.single.method, a2.requests.single.path],
          ['DELETE', '/event-groups/e1/budget-categories/b1']);
    });
  });

  group('VendorRepository', () {
    test('directory', () async {
      final (dio, a) = dioReturning(fixture('vendors_list'));
      final repo = VendorRepository(dio);
      await repo.listVendors();
      await repo.listVendors(const VendorFilters(
        priceTier: VendorPriceTier.luxury,
        category: 'catering',
        region: 'Pune',
      ));
      expect(a.requests[0].queryParameters, isEmpty);
      expect(a.requests[1].queryParameters, {'priceTier': 'luxury', 'category': 'catering', 'region': 'Pune'});

      final (dio2, a2) = dioReturning(fixture('vendor_detail'));
      await VendorRepository(dio2).getVendor('v1');
      expect(a2.requests.single.path, '/vendors/v1');

      final (dio3, a3) = dioReturning(fixture('vendor_categories'));
      expect(await VendorRepository(dio3).listCategories(), hasLength(10));
      expect(a3.requests.single.path, '/vendor-categories');
    });

    test('profile edits', () async {
      final (dio, a) = dioReturning(fixture('vendor_update_profile'));
      final repo = VendorRepository(dio);
      await repo.updateProfile(const UpdateVendorProfileBody(businessName: 'Shubh Photos', priceTier: VendorPriceTier.premium));
      await repo.setCategories(['photography']);
      expect([a.requests[0].method, a.requests[0].path], ['PATCH', '/vendor/me']);
      expect(a.requests[0].data, {'businessName': 'Shubh Photos', 'priceTier': 'premium'});
      expect([a.requests[1].method, a.requests[1].path], ['PUT', '/vendor/me/categories']);
      expect(a.requests[1].data, {'categoryKeys': ['photography']});
    });

    test('past work', () async {
      final (dio, a) = dioReturning(fixture('vendor_past_work_add'));
      final repo = VendorRepository(dio);
      await repo.addPastWork(const PastWorkBody(title: 'Sharma wedding', caption: 'Pune, 2025'));
      await repo.updatePastWork('p1', const PastWorkBody(title: 'New title'));
      await repo.deletePastWork('p1');
      await repo.reorderPastWork(['b', 'a']);
      expect(a.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /vendor/me/past-work',
        'PATCH /vendor/me/past-work/p1',
        'DELETE /vendor/me/past-work/p1',
        'PUT /vendor/me/past-work/order',
      ]);
      expect(a.requests[0].data, {'title': 'Sharma wedding', 'caption': 'Pune, 2025'});
      expect(a.requests[3].data, {'itemIds': ['b', 'a']});
    });

    test('me, submit, withdraw', () async {
      final (dio, a) = dioReturning(fixture('vendor_submit'));
      final repo = VendorRepository(dio);
      await repo.getMe();
      await repo.submit();
      await repo.withdraw();
      expect(a.requests.map((r) => '${r.method} ${r.path}'),
          ['GET /vendor/me', 'POST /vendor/me/submit', 'POST /vendor/me/withdraw']);
    });
  });
}
