import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/app.dart';

import 'helpers/container.dart';
import 'helpers/fake_adapter.dart';

void main() {
  testWidgets('app boots to the sign-in screen when signed out', (tester) async {
    final (container, _) = makeContainer(routes({}));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const SanchalanApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });
}
