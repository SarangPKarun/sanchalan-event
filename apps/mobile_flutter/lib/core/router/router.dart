import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/dev_routes.dart';
import '../../features/auth/otp_args.dart';
import '../../features/auth/otp_page.dart';
import '../../features/auth/phone_page.dart';
import '../../features/auth/unsupported_role_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/organizer/organizer_providers.dart';
import '../../features/organizer/pages/event_detail_page.dart';
import '../../features/organizer/pages/event_form_pages.dart';
import '../../features/organizer/pages/events_page.dart';
import '../../features/organizer/pages/home_page.dart';
import '../../features/organizer/pages/profile_pages.dart';
import '../../features/organizer/pages/vendors_pages.dart';
import '../../features/organizer/organizer_shell.dart';
import '../../features/vendor/pages/vendor_pages.dart';
import '../../features/vendor/vendor_providers.dart';
import '../../models/vendor.dart' show VendorRequiredField;
import '../../shared/widgets/data_error_screen.dart';
import '../../shared/widgets/data_loading_screen.dart';
import 'guard_state.dart';
import 'paths.dart';
import 'redirects.dart';

export '../../features/auth/otp_args.dart';

/// Re-runs the redirect rules whenever the guard state changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  /// A full-screen route that opens above the organizer tabs.
  GoRoute full(String path, Widget Function(GoRouterState state) builder) => GoRoute(
        path: path,
        parentNavigatorKey: rootKey,
        builder: (context, state) => builder(state),
      );

  GoRoute tab(String path, Widget Function(GoRouterState state) builder) =>
      GoRoute(path: path, builder: (context, state) => builder(state));

  final router = GoRouter(
    navigatorKey: rootKey,
    // Debug builds can open straight on a preview:
    // flutter run --dart-define=START_ROUTE=/dev/gallery
    initialLocation: kDebugMode
        ? const String.fromEnvironment('START_ROUTE', defaultValue: AppPaths.splash)
        : AppPaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(state.uri.toString(), ref.read(guardStateProvider)),
    routes: [
      GoRoute(path: AppPaths.splash, builder: (_, _) => const DataLoadingScreen()),
      GoRoute(path: AppPaths.unsupportedRole, builder: (_, _) => const UnsupportedRoleScreen()),

      // Design previews: debug builds only
      if (kDebugMode) ...devRoutes(),

      // Auth
      GoRoute(
        path: AppPaths.welcome,
        builder: (context, state) => WelcomeScreen(
          onGetStarted: () => context.go(AppPaths.phone),
          onDebugPreviews: kDebugMode ? () => context.push(AppPaths.dev) : null,
        ),
      ),
      GoRoute(path: AppPaths.phone, builder: (context, state) => const PhonePage()),
      GoRoute(
        path: AppPaths.otp,
        builder: (context, state) => OtpPage(args: state.extra! as OtpArgs),
        // The OTP screen needs to know who it is verifying.
        redirect: (context, state) => state.extra is OtpArgs ? null : AppPaths.phone,
      ),

      // Organizer: tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => OrganizerShell(
          body: shell,
          currentIndex: shell.currentIndex,
          onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
        branches: [
          StatefulShellBranch(routes: [tab(AppPaths.home, (_) => const HomePage())]),
          StatefulShellBranch(routes: [tab(AppPaths.events, (_) => const EventsPage())]),
          StatefulShellBranch(routes: [
            tab(AppPaths.vendors, (s) => VendorsPage(initialCategory: s.uri.queryParameters['category'])),
          ]),
          StatefulShellBranch(routes: [tab(AppPaths.profile, (_) => const OrganizerProfilePage())]),
        ],
      ),

      // Organizer: full-screen routes
      full(AppPaths.profileSetup, (_) => const ProfileSetupPage()),
      full(AppPaths.profileEdit, (_) => const ProfileEditPage()),
      full(AppPaths.eventSetup, (_) => const EventCreatePage()),
      full(
        AppPaths.eventHomePattern,
        (s) => EventDetailPage(
          id: s.pathParameters['id']!,
          args: s.extra is EventHomeArgs ? s.extra! as EventHomeArgs : null,
        ),
      ),
      full(AppPaths.eventEditPattern, (s) => EventEditPage(id: s.pathParameters['id']!)),
      full(AppPaths.vendorDetailPattern, (s) => VendorDetailPage(id: s.pathParameters['id']!)),
      GoRoute(
        path: AppPaths.organizerLoading,
        builder: (context, state) => const DataLoadingScreen(),
      ),
      GoRoute(
        path: AppPaths.organizerError,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => DataErrorScreen(
            onRetry: () => ref.read(organizerDataProvider.notifier).refetch(),
          ),
        ),
      ),

      // Vendor
      GoRoute(path: AppPaths.vendorHome, builder: (_, _) => const VendorDashboardPage()),
      GoRoute(
        path: AppPaths.vendorProfile,
        builder: (_, state) => VendorEditorPage(
          focusField: state.extra is VendorRequiredField ? state.extra! as VendorRequiredField : null,
        ),
      ),
      GoRoute(
        path: AppPaths.vendorLoading,
        builder: (context, state) => const DataLoadingScreen(),
      ),
      GoRoute(
        path: AppPaths.vendorError,
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => DataErrorScreen(
            onRetry: () => ref.read(vendorDataProvider.notifier).refetch(),
          ),
        ),
      ),
    ],
  );

  // go_router re-runs redirects on refresh only for the routes it navigated to itself, not for
  // screens opened with `push` (the editor, an event). So when the guard state changes, apply the
  // redirect for the current location explicitly: this is what moves a vendor off the editor after
  // submitting, or anyone off a pushed screen when their session expires.
  ref.listen(guardStateProvider, (_, next) {
    refresh.value++;
    final target = redirectFor(router.state.uri.toString(), next);
    if (target != null) router.go(target);
  });

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
