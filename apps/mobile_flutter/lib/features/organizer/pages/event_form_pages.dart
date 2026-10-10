import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/paths.dart';
import '../../../core/ui_feedback.dart';
import '../../../models/converters.dart';
import '../../../models/event.dart';
import '../../../shared/widgets/error_retry.dart';
import '../event_form_view.dart';
import '../organizer_providers.dart';
import '../organizer_repository.dart';

void _leave(BuildContext context, String fallback) => context.canPop() ? context.pop() : context.go(fallback);

/// New event. The server builds the budget with the LLM, so this can take a minute.
class EventCreatePage extends ConsumerWidget {
  const EventCreatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return EventFormView(
      onBack: () => _leave(context, AppPaths.events),
      onSubmit: (v, _) async {
        final EventGroup created;
        try {
          created = await ref.read(organizerRepositoryProvider).createEventGroup(
                CreateEventGroupBody(
                  eventType: v.type,
                  name: v.name,
                  region: v.region,
                  totalBudget: v.budget,
                  budgetTier: v.tier,
                  guestCountEstimate: v.guests,
                  primaryDate: toDateOnly(v.date),
                ),
              );
        } catch (e) {
          return friendlyError(e, 'Could not create the event. Please try again.');
        }
        await ref.read(organizerDataProvider.notifier).reloadEvents();
        ref.read(selectedEventIdProvider.notifier).select(created.id);
        // Replace the form, so Back from the new event goes to the list, not back to this form.
        if (context.mounted) context.pushReplacement(AppPaths.eventHome(created.id));
        return null;
      },
    );
  }
}

/// Edit an event's name, date, guests, budget and budget style.
class EventEditPage extends ConsumerWidget {
  const EventEditPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(eventDetailProvider(id));
    final event = detail.value;
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit event')),
        body: detail.hasError
            ? ErrorRetry(message: 'Could not load this event.', onRetry: () => ref.invalidate(eventDetailProvider(id)))
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return EventFormView(
      initial: event,
      onBack: () => _leave(context, AppPaths.eventHome(id)),
      onSubmit: (v, adjustment) async {
        final body = UpdateEventGroupBody(
          name: v.name != event.name ? v.name : null,
          totalBudget: v.budget != event.totalBudget ? v.budget : null,
          budgetTier: v.tier != event.budgetTier ? v.tier : null,
          guestCountEstimate: v.guests != event.guestCountEstimate ? v.guests : null,
          primaryDate: toDateOnly(v.date) != toDateOnly(event.primaryDate) ? toDateOnly(v.date) : null,
          budgetAdjustment: adjustment,
        );
        String? warning;
        if (body.toJson().isNotEmpty) {
          try {
            warning = (await ref.read(organizerRepositoryProvider).updateEventGroup(id, body)).warning;
          } catch (e) {
            return friendlyError(e, 'Could not save your changes. Please try again.');
          }
          ref.invalidate(eventDetailProvider(id));
          await ref.read(organizerDataProvider.notifier).reloadEvents();
        }
        if (context.mounted) {
          showToast(context, warning ?? 'Event updated');
          _leave(context, AppPaths.eventHome(id));
        }
        return null;
      },
    );
  }
}
