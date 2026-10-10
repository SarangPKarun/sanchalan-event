import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/offline_banner.dart';

class SanchalanApp extends ConsumerWidget {
  const SanchalanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Sanchalan',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => OfflineBannerHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
