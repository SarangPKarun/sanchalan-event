import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Rounded white surface with a hairline border and a soft shadow. Tappable
/// when [onTap] is set.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpace.l),
    this.color = AppColors.surface,
    this.borderColor = AppColors.outline,
    this.raised = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  /// Soft drop shadow; turn off for flat cards inside lists.
  final bool raised;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.l);
    final card = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: borderColor),
        boxShadow: raised ? AppShadows.soft : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    // A labelled card is announced as one element instead of reading every child.
    return semanticLabel == null
        ? card
        : Semantics(
            label: semanticLabel,
            button: onTap != null,
            onTap: onTap,
            excludeSemantics: true,
            child: card,
          );
  }
}
