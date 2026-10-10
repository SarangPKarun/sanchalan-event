import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'brand_mark.dart';

/// Shown while a session is restored or the account data loads.
class DataLoadingScreen extends StatelessWidget {
  const DataLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 72),
            SizedBox(height: AppSpace.xl),
            SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ],
        ),
      ),
    );
  }
}
