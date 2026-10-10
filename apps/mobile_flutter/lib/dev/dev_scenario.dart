import 'package:flutter/foundation.dart';

/// Data situations the organizer previews can show, switched from the debug bar.
enum DevScenario {
  normal('Normal'),
  noEvents('No events yet'),
  loading('Loading'),
  error('Error');

  const DevScenario(this.label);
  final String label;
}

final devScenario = ValueNotifier<DevScenario>(DevScenario.normal);
