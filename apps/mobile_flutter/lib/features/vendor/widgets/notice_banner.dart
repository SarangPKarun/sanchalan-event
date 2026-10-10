import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

enum NoticeTone { success, warning, error, info }

/// A short message with an icon on a tinted background.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.tone,
    required this.title,
    this.message,
    this.icon,
  });

  final NoticeTone tone;
  final String title;
  final String? message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (bg, fg, defaultIcon) = switch (tone) {
      NoticeTone.success => (AppColors.successBg, AppColors.successText, Icons.check_circle_outline),
      NoticeTone.warning => (AppColors.warningBg, AppColors.warningText, Icons.hourglass_top),
      NoticeTone.error => (AppColors.errorBg, AppColors.errorText, Icons.error_outline),
      NoticeTone.info => (AppColors.infoBg, AppColors.infoText, Icons.info_outline),
    };
    return Semantics(
      liveRegion: tone == NoticeTone.error,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.l)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon ?? defaultIcon, color: fg),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium?.copyWith(color: fg)),
                  if (message != null) ...[
                    const SizedBox(height: 2),
                    Text(message!, style: text.bodyMedium?.copyWith(color: fg)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
