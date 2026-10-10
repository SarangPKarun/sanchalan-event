/// Every route path in one place.
abstract final class AppPaths {
  // Shared
  static const splash = '/splash';
  static const unsupportedRole = '/unsupported-role';

  // Debug-only design previews (see lib/dev)
  static const dev = '/dev';

  // Auth
  static const welcome = '/welcome';
  static const phone = '/phone';
  static const otp = '/otp';

  // Organizer: the four tabs of the bottom navigation
  static const home = '/home';
  static const events = '/events';
  static const vendors = '/vendors';
  static const profile = '/profile';

  // Organizer: full-screen routes above the tabs
  static const profileSetup = '/profile-setup';
  static const profileEdit = '/profile-edit';
  static const eventSetup = '/event-setup';
  static const eventHomePattern = '/event-home/:id';
  static String eventHome(String id) => '/event-home/$id';
  static const eventEditPattern = '/event-edit/:id';
  static String eventEdit(String id) => '/event-edit/$id';
  static const vendorDetailPattern = '/vendors/:id';
  static String vendorDetail(String id) => '/vendors/$id';
  static const organizerLoading = '/organizer/loading';
  static const organizerError = '/organizer/error';

  // Vendor
  static const vendorHome = '/vendor/home';
  static const vendorProfile = '/vendor/profile';
  static const vendorLoading = '/vendor/loading';
  static const vendorError = '/vendor/error';

  /// Screens a signed-out user can see.
  static bool isAuthPath(String path) => path == welcome || path == phone || path == otp;

  /// Organizer screens reachable once the profile is complete.
  static bool isOrganizerAppPath(String path) =>
      path == home ||
      path == events ||
      path == vendors ||
      path == profile ||
      path == profileEdit ||
      path == eventSetup ||
      path.startsWith('/event-home/') ||
      path.startsWith('/event-edit/') ||
      path.startsWith('/vendors/');
}
