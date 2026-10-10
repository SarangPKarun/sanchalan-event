import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Yes/no question. Returns true only when the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive ? TextButton.styleFrom(foregroundColor: AppColors.errorText) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
