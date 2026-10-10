import 'package:flutter/foundation.dart';

import '../../features/auth/auth_state.dart';
import '../../models/enums.dart';
import 'guard_state.dart';
import 'paths.dart';

/// Where to send the user from [location], or null to stay. Replaces the
/// `Stack.Protected` guards of the React Native layouts. Pure, so it is
/// unit-tested as a table; go_router just calls it.
///
/// [allowDev] lets the debug-only `/dev` design previews through the guards;
/// it is false in release builds.
String? redirectFor(String location, GuardState g, {bool allowDev = kDebugMode}) {
  final path = Uri.parse(location).path;
  String? to(String target) => path == target ? null : target;

  if (allowDev && (path == AppPaths.dev || path.startsWith('${AppPaths.dev}/'))) return null;

  switch (g.auth.status) {
    case AuthStatus.loading:
      return to(AppPaths.splash);
    case AuthStatus.unauthed:
      return AppPaths.isAuthPath(path) ? null : AppPaths.welcome;
    case AuthStatus.authed:
      break;
  }

  switch (g.auth.role!) {
    case AuthRole.admin:
      // The mobile app has no admin screens.
      return to(AppPaths.unsupportedRole);

    case AuthRole.organizer:
      switch (g.organizer ?? OrganizerPhase.loading) {
        case OrganizerPhase.loading:
          return to(AppPaths.organizerLoading);
        case OrganizerPhase.error:
          return to(AppPaths.organizerError);
        case OrganizerPhase.needsProfile:
          return to(AppPaths.profileSetup);
        case OrganizerPhase.ready:
          return AppPaths.isOrganizerAppPath(path) ? null : AppPaths.home;
      }

    case AuthRole.vendor:
      final phase = g.vendor ?? VendorPhase.loading;
      switch (phase) {
        case VendorPhase.loading:
          return to(AppPaths.vendorLoading);
        case VendorPhase.error:
          return to(AppPaths.vendorError);
        default:
          return allowedVendorPaths(phase).contains(path) ? null : defaultVendorPath(phase);
      }
  }
}

/// Every vendor lands on the dashboard, which changes with the status.
String defaultVendorPath(VendorPhase phase) => switch (phase) {
      VendorPhase.loading => AppPaths.vendorLoading,
      VendorPhase.error => AppPaths.vendorError,
      _ => AppPaths.vendorHome,
    };

/// Screens a vendor may open in each status. The profile editor is for
/// vendors who can edit (draft, rejected, published); a pending or suspended
/// vendor only sees the dashboard.
Set<String> allowedVendorPaths(VendorPhase phase) => switch (phase) {
      VendorPhase.draft || VendorPhase.rejected || VendorPhase.published => {
          AppPaths.vendorHome,
          AppPaths.vendorProfile,
        },
      VendorPhase.pendingReview || VendorPhase.suspended => {AppPaths.vendorHome},
      VendorPhase.loading || VendorPhase.error => const {},
    };
