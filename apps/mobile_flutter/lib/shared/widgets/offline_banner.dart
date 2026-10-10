import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Wraps the whole app: shows a slim "No connection" strip at the top while the
/// phone is offline. Network failures never sign anyone out; this just explains
/// why things may not load.
class OfflineBannerHost extends ConsumerWidget {
  const OfflineBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOnlineProvider).value == false;
    return Column(
      children: [
        AnimatedSize(
          duration: AppMotion.normal,
          alignment: Alignment.topCenter,
          child: offline
              ? Semantics(
                  liveRegion: true,
                  child: Material(
                    color: AppColors.ink,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.s),
                        child: Row(
                          children: [
                            const Icon(Icons.cloud_off_outlined, color: AppColors.surface, size: 18),
                            const SizedBox(width: AppSpace.s),
                            Expanded(
                              child: Text(
                                'No connection. Some things may not load.',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.surface),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          // The banner already covers the status bar, so the screen below must not pad for it twice.
          child: MediaQuery.removePadding(context: context, removeTop: offline, child: child),
        ),
      ],
    );
  }
}
