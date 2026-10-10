import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Thin strip above a preview that says it is a preview and switches the data
/// scenario. Debug only.
class DevBar<T> extends StatelessWidget {
  const DevBar({super.key, required this.notifier, required this.options, required this.labelOf});

  final ValueNotifier<T> notifier;
  final List<T> options;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to previews',
                icon: const Icon(Icons.close, color: AppColors.surface, size: 20),
                onPressed: () => context.go('/dev'),
              ),
              Text('PREVIEW', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.goldContainer)),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ValueListenableBuilder<T>(
                    valueListenable: notifier,
                    builder: (context, current, _) => PopupMenuButton<T>(
                      tooltip: 'Data scenario',
                      initialValue: current,
                      onSelected: (s) => notifier.value = s,
                      itemBuilder: (_) => [for (final o in options) PopupMenuItem(value: o, child: Text(labelOf(o)))],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Scenario: ${labelOf(current)}',
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.surface),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppColors.surface),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
