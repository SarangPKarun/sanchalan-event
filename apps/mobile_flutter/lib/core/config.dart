import 'package:flutter/foundation.dart';

/// Backend base URL. Override per build with `--dart-define=API_URL=...`.
/// Debug builds default to a local backend from the Android emulator (10.0.2.2 is the host
/// loopback). Release builds have no default: a missing API_URL is caught at startup.
const apiUrl = String.fromEnvironment('API_URL', defaultValue: kReleaseMode ? '' : 'http://10.0.2.2:3000');

/// Where suspended vendors are sent for help. Placeholders until the real
/// contact exists; set per build with --dart-define=SUPPORT_EMAIL=... and SUPPORT_PHONE=...
const supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'support@sanchalan.app');
const supportPhone = String.fromEnvironment('SUPPORT_PHONE', defaultValue: '');
