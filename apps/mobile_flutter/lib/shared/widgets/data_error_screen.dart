import 'package:flutter/material.dart';

import 'error_retry.dart';

/// "Something went wrong" with a Retry button, shown when loading the account
/// data fails (offline, server error).
class DataErrorScreen extends StatelessWidget {
  const DataErrorScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ErrorRetry(
          message: 'Something went wrong loading your account.',
          onRetry: onRetry,
        ),
      ),
    );
  }
}
