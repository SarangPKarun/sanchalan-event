import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/empty_state.dart';
import 'auth_controller.dart';

/// An admin session found on the mobile app, which has no admin screens.
class UnsupportedRoleScreen extends ConsumerWidget {
  const UnsupportedRoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Not available here',
          message: 'This account type is not supported in the mobile app.',
          actionLabel: 'Sign out',
          onAction: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ),
    );
  }
}
