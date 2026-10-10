import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'brand_mark.dart';

/// Stand-in for a screen that is built in Phase 7 (after the design sign-off).
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key, this.detail, this.actions = const []});

  final String title;
  final String? detail;

  /// Extra widgets under the title (e.g. a debug shortcut).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 56),
                const SizedBox(height: AppSpace.l),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (detail != null) ...[
                  const SizedBox(height: AppSpace.s),
                  Text(detail!, textAlign: TextAlign.center),
                ],
                for (final a in actions) ...[const SizedBox(height: AppSpace.l), a],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
