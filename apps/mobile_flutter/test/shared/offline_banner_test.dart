import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/app.dart';
import 'package:sanchalan/core/connectivity.dart';

import '../helpers/container.dart';
import '../helpers/fake_adapter.dart';

class FakeConnectivity implements ConnectivityService {
  FakeConnectivity(this.initial);
  final bool initial;
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isOnline() async => initial;
  @override
  Stream<bool> get onChanged => controller.stream;
}

Future<void> pumpApp(WidgetTester tester, FakeConnectivity c) async {
  final (container, _) = makeContainer(
    routes({}),
    overrides: [connectivityServiceProvider.overrideWithValue(c)],
  );
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const SanchalanApp()));
  await tester.pumpAndSettle();
}

void main() {
  const message = 'No connection. Some things may not load.';

  testWidgets('no banner while online', (tester) async {
    await pumpApp(tester, FakeConnectivity(true));
    expect(find.text(message), findsNothing);
  });

  testWidgets('the banner appears when the phone starts offline', (tester) async {
    await pumpApp(tester, FakeConnectivity(false));
    expect(find.text(message), findsOneWidget);
    // The app underneath is still usable.
    expect(find.text('Plan every celebration, stress-free'), findsOneWidget);
  });

  testWidgets('it follows the connection coming and going', (tester) async {
    final c = FakeConnectivity(true);
    await pumpApp(tester, c);
    expect(find.text(message), findsNothing);

    c.controller.add(false);
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);

    c.controller.add(true);
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
  });
}
