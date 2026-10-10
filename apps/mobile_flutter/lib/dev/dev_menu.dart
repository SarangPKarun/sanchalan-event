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
  DevEntry('/dev/gallery', 'Design gallery', 'Colors, type and every widget'),
  DevEntry('/dev/welcome', 'Welcome to sign-in flow', 'Welcome, then phone, then OTP (mock)'),
  DevEntry('/dev/phone', 'Phone number', 'Role choice and number entry (mock)'),
  DevEntry('/dev/otp', 'OTP', 'Six-digit code, any code except 123456 fails (mock)'),
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
