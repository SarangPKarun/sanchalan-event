import '../../features/auth/auth_state.dart';
import '../../models/enums.dart';
import 'guard_state.dart';
import 'paths.dart';

/// Where to send the user from [location], or null to stay. Replaces the
/// `Stack.Protected` guards of the React Native layouts. Pure, so it is
/// unit-tested as a table; go_router just calls it.
String? redirectFor(String location, GuardState g) {
  final path = Uri.parse(location).path;
  String? to(String target) => path == target ? null : target;

  switch (g.auth.status) {
    case AuthStatus.loading:
      return to(AppPaths.splash);
    case AuthStatus.unauthed:
      return path == AppPaths.phone || path == AppPaths.otp ? null : AppPaths.phone;
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
          return AppPaths.isOrganizerAppPath(path) ? null : AppPaths.events;
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

/// The vendor screen each status lands on.
String defaultVendorPath(VendorPhase phase) => switch (phase) {
      VendorPhase.published => AppPaths.vendorHome,
      VendorPhase.pendingReview => AppPaths.vendorUnderReview,
      VendorPhase.suspended => AppPaths.vendorSuspended,
      VendorPhase.draft || VendorPhase.rejected => AppPaths.vendorProfile,
      VendorPhase.loading => AppPaths.vendorLoading,
      VendorPhase.error => AppPaths.vendorError,
    };

/// Screens a vendor may open in each status. A published vendor reaches the
/// profile editor through "Edit"; the other statuses are locked to one screen.
Set<String> allowedVendorPaths(VendorPhase phase) => switch (phase) {
      VendorPhase.published => {AppPaths.vendorHome, AppPaths.vendorProfile},
      VendorPhase.loading || VendorPhase.error => const {},
      _ => {defaultVendorPath(phase)},
    };
