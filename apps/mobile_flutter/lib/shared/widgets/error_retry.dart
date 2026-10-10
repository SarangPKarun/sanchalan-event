import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'primary_button.dart';

/// Plain-language error with a Retry button.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({
    super.key,
    this.message = 'Something went wrong. Please try again.',
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpace.l),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: AppSpace.xl),
            PrimaryButton(label: 'Retry', onPressed: onRetry, expand: false, icon: Icons.refresh),
          ],
        ),
      ),
    );
  }
}
