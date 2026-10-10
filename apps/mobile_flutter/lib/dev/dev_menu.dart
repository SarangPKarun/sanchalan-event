import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';
import '../shared/widgets/app_card.dart';

/// Entry in the debug-only previews list.
class DevEntry {
  const DevEntry(this.path, this.title, this.subtitle);
  final String path;
  final String title;
  final String subtitle;
}

const devEntries = [
  // Sign-in
  DevEntry('/dev/welcome', 'Sign-in flow', 'Welcome, then phone, then OTP (mock)'),
  DevEntry('/dev/phone', 'Phone number', 'Role choice and number entry (mock)'),
  DevEntry('/dev/otp', 'OTP', 'Six-digit code; 123456 succeeds, anything else fails (mock)'),
  // Organizer
  DevEntry('/dev/o/home', 'Organizer app', 'Home, Events, Vendors, Profile with a data scenario switcher'),
  DevEntry('/dev/o/event/ev-wedding', 'Event detail', 'Roadmap, Budget and Vendors tabs; tasks and budget are editable'),
  DevEntry('/dev/o/event/ev-new', 'Event without a roadmap', 'Generate flow with the waiting screen'),
  DevEntry('/dev/o/new-event', 'New event form', 'A name containing "fail" shows the error state'),
  DevEntry('/dev/o/edit-event/ev-wedding', 'Edit event form', 'Change the budget to see the rescale choice'),
  DevEntry('/dev/o/profile-setup', 'Profile setup', 'Name and who is organizing'),
  DevEntry('/dev/o/vendor/v1', 'Vendor detail', 'Facts, past work, links, Call and WhatsApp'),
  // Design system
  DevEntry('/dev/gallery', 'Design gallery', 'Colors, type and every widget'),
];

/// Debug-only list of design previews, reachable from the sign-in placeholder.
class DevMenuScreen extends StatelessWidget {
  const DevMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design previews')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        children: [
          for (final e in devEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.m),
              child: AppCard(
                onTap: () => context.push(e.path),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title, style: Theme.of(context).textTheme.titleMedium),
                          Text(e.subtitle, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
