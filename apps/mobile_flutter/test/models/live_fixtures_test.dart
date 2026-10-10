import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/models/auth.dart';
import 'package:sanchalan/models/event.dart';
import 'package:sanchalan/models/organizer.dart';
import 'package:sanchalan/models/roadmap.dart';
import 'package:sanchalan/models/vendor.dart';

// Real responses recorded from the backend (test/fixtures/live/*.json, run
// against a throwaway database with tokens redacted). If an endpoint's shape
// changes, re-record them and these tests show what the models must follow.

Object? load(String name) =>
    jsonDecode(File('test/fixtures/live/$name.json').readAsStringSync());

Map<String, dynamic> obj(String name) => load(name) as Map<String, dynamic>;

void main() {
  group('auth', () {
    test('verify / admin login', () {
      expect(AuthTokens.fromJson(obj('auth_verify_organizer')).userId, isNotEmpty);
      expect(AuthTokens.fromJson(obj('admin_login')).adminRole, isNotNull);
    });
    test('refresh', () => expect(RefreshResponse.fromJson(obj('refresh')).accessToken, isNotEmpty));
  });

  group('organizer', () {
    test('fresh and after profile setup', () {
      final fresh = Organizer.fromJson(obj('organizer_me_fresh'));
      expect(fresh.displayName, isNull);
      expect(fresh.organizerType, isNull);
      final done = Organizer.fromJson(obj('organizer_profile'));
      expect(done.displayName, 'Priya Sharma');
    });
  });

  group('events', () {
    test('create has sub-events and budget categories', () {
      final eg = EventGroup.fromJson(obj('event_group_create'));
      expect(eg.subEvents, isNotEmpty);
      expect(eg.budgetCategories, isNotEmpty);
      expect(eg.totalBudget, 1500000);
    });
    test('list items parse', () {
      final list = (load('event_groups_me') as List).cast<Map<String, dynamic>>();
      expect(list.map(EventGroup.fromJson), isNotEmpty);
    });
    test('detail has tasks after generating a roadmap', () {
      final eg = EventGroup.fromJson(obj('event_group_detail'));
      expect(eg.tasks, isNotEmpty);
      expect(eg.budgetCategories, isNotEmpty);
    });
    test('update, budget category mutations', () {
      expect(UpdateEventGroupResponse.fromJson(obj('event_group_update')).eventGroup.totalBudget,
          1800000);
      expect(BudgetCategoryMutationResponse.fromJson(obj('budget_category_create'))
          .budgetCategory.categoryKey, 'gifts');
      expect(BudgetCategoryMutationResponse.fromJson(obj('budget_category_update'))
          .budgetCategory.allocatedAmount, 90000);
      expect(DeleteBudgetCategoryResponse.fromJson(obj('budget_category_delete'))
          .budgetCategories, isNotEmpty);
    });
  });

  group('roadmap', () {
    test('generate', () {
      final r = GenerateRoadmapResponse.fromJson(obj('roadmap_generate'));
      expect(r.tasks, isNotEmpty);
    });
    test('task list', () {
      final r = ListEventGroupTasksResponse.fromJson(obj('event_group_tasks'));
      expect(r.tasks, isNotEmpty);
    });
    test('task update / create / delete', () {
      expect(Task.fromJson(obj('task_update')).name, isNotEmpty);
      expect(TaskWithDependencies.fromJson(obj('task_create')).name, 'Buy gifts');
      expect(Task.fromJson(obj('task_delete')).id, isNotEmpty);
    });
    test('task categories', () {
      expect(ListTaskCategoriesResponse.fromJson(obj('task_categories')).categories, isNotEmpty);
    });
  });

  group('vendor', () {
    test('categories', () {
      expect(ListVendorCategoriesResponse.fromJson(obj('vendor_categories')).categories,
          hasLength(10));
    });
    test('draft, submit, published self views', () {
      final draft = VendorMeResponse.fromJson(obj('vendor_me_draft'));
      expect(draft.completeness.complete, isFalse);
      expect(draft.completeness.missing, isNotEmpty);
      expect(VendorMeResponse.fromJson(obj('vendor_submit')).vendor.status.name, 'pendingReview');
      expect(VendorMeResponse.fromJson(obj('vendor_me_published')).vendor.status.name, 'published');
    });
    test('profile, category and past-work edits', () {
      for (final f in ['vendor_update_profile', 'vendor_set_categories', 'vendor_past_work_add']) {
        final r = UpdateVendorProfileResponse.fromJson(obj(f));
        expect(r.vendor.vendor.businessName, 'Shubh Photos', reason: f);
      }
    });
    test('organizer browse', () {
      final list = ListVendorsResponse.fromJson(obj('vendors_list')).vendors;
      expect(list.single.startingPrice, 50000);
      expect(list.single.categoryKeys, ['photography']);
      expect(Vendor.fromJson(obj('vendor_detail')).portfolioItems, hasLength(1));
    });
    test('admin endpoints (React admin keeps its own client; models still parse)', () {
      expect(ListVendorsResponse.fromJson(obj('admin_vendors_list')).vendors, isNotEmpty);
      expect(Vendor.fromJson(obj('admin_vendor_approve')).status.name, 'published');
    });
  });
}
