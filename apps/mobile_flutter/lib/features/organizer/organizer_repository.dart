import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/enums.dart';
import '../../models/event.dart';
import '../../models/event_profile.dart';
import '../../models/organizer.dart';
import '../../models/roadmap.dart';

/// Calls the server makes with an LLM (budget split, roadmap) can exceed the
/// default timeout. Same 90 s the React Native screens used.
final _llmOptions = Options(receiveTimeout: const Duration(seconds: 90));

List<Map<String, dynamic>> _list(Object? data) => (data as List).cast<Map<String, dynamic>>();

class OrganizerRepository {
  OrganizerRepository(this._dio);
  final Dio _dio;

  Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? query}) async =>
      (await _dio.get<Map<String, dynamic>>(path, queryParameters: query)).data!;

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Options? options,
  }) async {
    final res = await _dio.request<Map<String, dynamic>>(
      path,
      data: body,
      options: (options ?? Options()).copyWith(method: method),
    );
    return res.data!;
  }

  // --- profile ---

  Future<Organizer> getMe() async => Organizer.fromJson(await _get('/organizers/me'));

  Future<Organizer> updateProfile(UpdateOrganizerProfileBody body) async =>
      Organizer.fromJson(await _send('POST', '/organizers/me/profile', body: body.toJson()));

  // --- events ---

  /// The organizer's events with sub-events (no budget categories or tasks).
  Future<List<EventGroup>> listEventGroups() async {
    final res = await _dio.get<List<dynamic>>('/event-groups/me');
    return _list(res.data).map(EventGroup.fromJson).toList();
  }

  /// One event with sub-events, budget categories and tasks.
  Future<EventGroup> getEventGroup(String id) async =>
      EventGroup.fromJson(await _get('/event-groups/$id'));

  /// The creation flow (questions) for every event type. Static on the server.
  Future<List<EventTypeProfile>> listEventTypeProfiles() async {
    final res = await _dio.get<List<dynamic>>('/event-types');
    return _list(res.data).map(EventTypeProfile.fromJson).toList();
  }

  /// Asks the server (an LLM call) to write the questions for an event type we have no form for.
  Future<GeneratedProfile> generateEventProfile(String description) async => GeneratedProfile.fromJson(
        await _send('POST', '/event-types/generate', body: {'description': description}, options: _llmOptions),
      );

  /// The server builds the budget categories with the LLM, so this is slow.
  Future<EventGroup> createEventGroup(CreateEventGroupBody body) async => EventGroup.fromJson(
        await _send('POST', '/event-groups', body: body.toJson(), options: _llmOptions),
      );

  Future<UpdateEventGroupResponse> updateEventGroup(String id, UpdateEventGroupBody body) async =>
      UpdateEventGroupResponse.fromJson(
        await _send('PATCH', '/event-groups/$id', body: body.toJson()),
      );

  Future<DeleteEventGroupResponse> deleteEventGroup(String id) async =>
      DeleteEventGroupResponse.fromJson(await _send('DELETE', '/event-groups/$id'));

  // --- roadmap / tasks ---

  /// Generate or regenerate the roadmap. [mode] is only sent on a re-run.
  Future<GenerateRoadmapResponse> generateRoadmap(String eventGroupId, {RoadmapRegenMode? mode}) async =>
      GenerateRoadmapResponse.fromJson(await _send(
        'POST',
        '/event-groups/$eventGroupId/generate-roadmap',
        body: GenerateRoadmapBody(mode: mode).toJson(),
        options: _llmOptions,
      ));

  Future<List<TaskWithDependencies>> listTasks(
    String eventGroupId, {
    bool includeNotApplicable = false,
  }) async {
    final json = await _get(
      '/event-groups/$eventGroupId/tasks',
      query: includeNotApplicable ? {'includeNotApplicable': true} : null,
    );
    return ListEventGroupTasksResponse.fromJson(json).tasks;
  }

  Future<TaskWithDependencies> createTask(String eventGroupId, CreateTaskBody body) async =>
      TaskWithDependencies.fromJson(
        await _send('POST', '/event-groups/$eventGroupId/tasks', body: body.toJson()),
      );

  Future<Task> updateTask(String taskId, UpdateTaskBody body) async =>
      Task.fromJson(await _send('PATCH', '/tasks/$taskId', body: body.toJson()));

  /// Soft delete: the task becomes `not_applicable`.
  Future<Task> deleteTask(String taskId) async =>
      Task.fromJson(await _send('DELETE', '/tasks/$taskId'));

  Future<List<TaskCategory>> listTaskCategories() async =>
      ListTaskCategoriesResponse.fromJson(await _get('/task-categories')).categories;

  // --- budget ---

  Future<BudgetCategoryMutationResponse> createBudgetCategory(
    String eventGroupId,
    CreateBudgetCategoryBody body,
  ) async =>
      BudgetCategoryMutationResponse.fromJson(
        await _send('POST', '/event-groups/$eventGroupId/budget-categories', body: body.toJson()),
      );

  Future<BudgetCategoryMutationResponse> updateBudgetCategory(
    String eventGroupId,
    String categoryId,
    UpdateBudgetCategoryBody body,
  ) async =>
      BudgetCategoryMutationResponse.fromJson(await _send(
        'PATCH',
        '/event-groups/$eventGroupId/budget-categories/$categoryId',
        body: body.toJson(),
      ));

  Future<DeleteBudgetCategoryResponse> deleteBudgetCategory(
    String eventGroupId,
    String categoryId,
  ) async =>
      DeleteBudgetCategoryResponse.fromJson(
        await _send('DELETE', '/event-groups/$eventGroupId/budget-categories/$categoryId'),
      );
}

final organizerRepositoryProvider =
    Provider<OrganizerRepository>((ref) => OrganizerRepository(ref.watch(dioProvider)));
