import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/theme/app_theme.dart';

/// Pumps [child] inside the app theme at a given logical size and text scale.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 640),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: child,
  ));
  // Skeletons and spinners animate forever, so settle with a fixed number of frames.
  await tester.pump(const Duration(milliseconds: 100));
}
