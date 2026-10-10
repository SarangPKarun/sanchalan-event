import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/paths.dart';
import '../../../core/ui_feedback.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/data_error_screen.dart';
import '../../../shared/widgets/data_loading_screen.dart';
import '../../auth/auth_controller.dart';
import '../organizer_profile_view.dart';
import '../organizer_providers.dart';
import '../organizer_repository.dart';
import '../profile_setup_view.dart';

/// First-time profile step after sign-in. When saved, the data is reloaded and
/// the router moves the organizer to the home tab.
class ProfileSetupPage extends ConsumerWidget {
  const ProfileSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfileSetupView(
      onSubmit: (body) async {
        try {
          await ref.read(organizerRepositoryProvider).updateProfile(body);
        } catch (e) {
          return friendlyError(e, 'Could not save your profile. Please try again.');
        }
        await ref.read(organizerDataProvider.notifier).refetch();
        return null;
      },
    );
  }
}

/// Edit the saved profile from the Profile tab.
class ProfileEditPage extends ConsumerWidget {
  const ProfileEditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(organizerDataProvider).value;
    if (data is! OrganizerReady) return const DataLoadingScreen();
    return ProfileSetupView(
      initial: data.organizer,
      onBack: () => context.canPop() ? context.pop() : context.go(AppPaths.profile),
      onSubmit: (body) async {
        try {
          final updated = await ref.read(organizerRepositoryProvider).updateProfile(body);
          ref.read(organizerDataProvider.notifier).setOrganizer(updated);
        } catch (e) {
          return friendlyError(e, 'Could not save your profile. Please try again.');
        }
        if (context.mounted) {
          showToast(context, 'Profile updated');
          context.canPop() ? context.pop() : context.go(AppPaths.profile);
        }
        return null;
      },
    );
  }
}

/// Profile tab.
class OrganizerProfilePage extends ConsumerWidget {
  const OrganizerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(organizerDataProvider);
    final data = async.value;
    if (data is! OrganizerReady) {
      return async.hasError
          ? DataErrorScreen(onRetry: () => ref.read(organizerDataProvider.notifier).refetch())
          : const DataLoadingScreen();
    }
    return OrganizerProfileView(
      organizer: data.organizer,
      onEdit: () => context.push(AppPaths.profileEdit),
      onSignOut: () async {
        final yes = await showConfirmDialog(
          context,
          title: 'Sign out?',
          message: 'You will need your phone number and a new code to sign back in.',
          confirmLabel: 'Sign out',
          destructive: true,
        );
        if (yes) await ref.read(authControllerProvider.notifier).signOut();
      },
    );
  }
}
