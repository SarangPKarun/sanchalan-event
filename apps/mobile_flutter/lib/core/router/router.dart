import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dev/dev_routes.dart';
import '../../features/auth/unsupported_role_screen.dart';
import '../../features/auth/welcome_screen.dart';
import '../../features/organizer/organizer_providers.dart';
import '../../features/organizer/organizer_shell.dart';
import '../../features/vendor/vendor_providers.dart';
import '../../models/enums.dart';
import '../../shared/widgets/data_error_screen.dart';
import '../../shared/widgets/data_loading_screen.dart';
import '../../shared/widgets/placeholder_screen.dart';
import '../../shared/widgets/primary_button.dart';
import 'guard_state.dart';
import 'paths.dart';
import 'redirects.dart';

/// Passed as `extra` when going from the phone screen to the OTP screen.
class OtpArgs {
  const OtpArgs({required this.phoneNumber, required this.role});

  final String phoneNumber;
  final AuthRole role;
}

/// Re-runs the redirect rules whenever the guard state changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(guardStateProvider, (_, _) => refresh.value++);
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
        builder: (context, state) => WelcomeScreen(onGetStarted: () => context.go(AppPaths.phone)),
      ),
      GoRoute(
        path: AppPaths.phone,
        builder: (context, state) => PlaceholderScreen(
          'Sign in',
          actions: [
            if (kDebugMode)
              SecondaryButton(
                label: 'Design previews',
                expand: false,
                onPressed: () => context.push(AppPaths.dev),
              ),
          ],
        ),
      ),
      GoRoute(
        path: AppPaths.otp,
        builder: (context, state) {
          final args = state.extra! as OtpArgs;
          return PlaceholderScreen('Verify OTP', detail: args.phoneNumber);
        },
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
          StatefulShellBranch(routes: [tab(AppPaths.home, (_) => const PlaceholderScreen('Home'))]),
          StatefulShellBranch(routes: [tab(AppPaths.events, (_) => const PlaceholderScreen('My events'))]),
          StatefulShellBranch(routes: [
            tab(AppPaths.vendors, (s) => PlaceholderScreen('Vendors', detail: s.uri.queryParameters['category'])),
          ]),
          StatefulShellBranch(routes: [tab(AppPaths.profile, (_) => const PlaceholderScreen('Profile'))]),
        ],
      ),

      // Organizer: full-screen routes
      full(AppPaths.profileSetup, (_) => const PlaceholderScreen('Set up your profile')),
      full(AppPaths.profileEdit, (_) => const PlaceholderScreen('Edit profile')),
      full(AppPaths.eventSetup, (_) => const PlaceholderScreen('New event')),
      full(AppPaths.eventHomePattern, (s) => PlaceholderScreen('Event', detail: s.pathParameters['id'])),
      full(AppPaths.eventEditPattern, (s) => PlaceholderScreen('Edit event', detail: s.pathParameters['id'])),
      full(AppPaths.vendorDetailPattern, (s) => PlaceholderScreen('Vendor', detail: s.pathParameters['id'])),
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
      GoRoute(path: AppPaths.vendorHome, builder: (_, _) => const PlaceholderScreen('Vendor home')),
      GoRoute(path: AppPaths.vendorProfile, builder: (_, _) => const PlaceholderScreen('Vendor profile')),
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

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
