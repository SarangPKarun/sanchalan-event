import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/organizer.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/primary_button.dart';
import 'widgets/vendor_card.dart';

/// Profile tab: who is signed in, with an option to edit and to sign out.
class OrganizerProfileView extends StatelessWidget {
  const OrganizerProfileView({super.key, required this.organizer, this.onEdit, this.onSignOut});

  final Organizer organizer;
  final VoidCallback? onEdit;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = organizer.displayName ?? 'Organizer';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profile'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s, AppSpace.gutter, AppSpace.xxl),
        children: [
          AppCard(
            child: Column(
              children: [
                VendorAvatar(name: name, size: 72),
                const SizedBox(height: AppSpace.m),
                Text(name, style: text.headlineSmall, textAlign: TextAlign.center),
                if (organizer.organizerType != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${organizerTypeLabel(organizer.organizerType!)} organizer',
                      style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
                const SizedBox(height: AppSpace.l),
                const Divider(),
                const SizedBox(height: AppSpace.m),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, color: AppColors.maroon),
                    const SizedBox(width: AppSpace.m),
                    Expanded(child: Text(organizer.phoneNumber, style: text.titleMedium)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.m),
          SecondaryButton(label: 'Edit profile', icon: Icons.edit_outlined, onPressed: onEdit),
          const SizedBox(height: AppSpace.xxl),
          TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorText),
          ),
        ],
      ),
    );
  }
}
