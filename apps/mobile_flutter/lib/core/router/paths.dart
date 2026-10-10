/// Every route path in one place. Screens are built in Phase 7; until then each
/// path renders a placeholder.
abstract final class AppPaths {
  // Shared
  static const splash = '/splash';
  static const unsupportedRole = '/unsupported-role';

  // Debug-only design previews (see lib/dev)
  static const dev = '/dev';

  // Auth
  static const phone = '/phone';
  static const otp = '/otp';

  // Organizer
  static const profileSetup = '/profile-setup';
  static const events = '/events';
  static const eventSetup = '/event-setup';
  static const eventHomePattern = '/event-home/:id';
  static String eventHome(String id) => '/event-home/$id';
  static const vendors = '/vendors';
  static const vendorDetailPattern = '/vendors/:id';
  static String vendorDetail(String id) => '/vendors/$id';
  static const organizerLoading = '/organizer/loading';
  static const organizerError = '/organizer/error';

  // Vendor
  static const vendorHome = '/vendor/home';
  static const vendorProfile = '/vendor/profile';
  static const vendorUnderReview = '/vendor/under-review';
  static const vendorSuspended = '/vendor/suspended';
  static const vendorLoading = '/vendor/loading';
  static const vendorError = '/vendor/error';

  /// Organizer screens reachable once the profile is complete.
  static bool isOrganizerAppPath(String path) =>
      path == events ||
      path == eventSetup ||
      path.startsWith('/event-home/') ||
      path == vendors ||
      path.startsWith('/vendors/');
}
