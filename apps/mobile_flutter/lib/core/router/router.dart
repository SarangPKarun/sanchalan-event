import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/unsupported_role_screen.dart';
import '../../features/organizer/organizer_providers.dart';
import '../../features/vendor/vendor_providers.dart';
import '../../models/enums.dart';
import '../../shared/widgets/data_error_screen.dart';
import '../../shared/widgets/data_loading_screen.dart';
import '../../shared/widgets/placeholder_screen.dart';
import 'guard_state.dart';
import 'paths.dart';
import 'redirects.dart';

/// Passed as `extra` when going from the phone screen to the OTP screen.
class OtpArgs {
  const OtpArgs({required this.phoneNumber, required this.role});

  final String phoneNumber;
  final AuthRole role;
}

GoRoute _route(String path, Widget Function(GoRouterState state) builder, {GoRouterRedirect? redirect}) =>
    GoRoute(path: path, redirect: redirect, builder: (context, state) => builder(state));

/// Re-runs the redirect rules whenever the guard state changes.
/// Screens are placeholders until Phase 7; the guard logic is final.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(guardStateProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: AppPaths.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(state.uri.toString(), ref.read(guardStateProvider)),
    routes: [
      _route(AppPaths.splash, (_) => const DataLoadingScreen()),
      _route(AppPaths.unsupportedRole, (_) => const UnsupportedRoleScreen()),

      // Auth
      _route(AppPaths.phone, (_) => const PlaceholderScreen('Sign in')),
      _route(
        AppPaths.otp,
        (state) {
          final args = state.extra! as OtpArgs;
          return PlaceholderScreen('Verify OTP', detail: args.phoneNumber);
        },
        // The OTP screen needs to know who it is verifying.
        redirect: (context, state) => state.extra is OtpArgs ? null : AppPaths.phone,
      ),

      // Organizer
      _route(AppPaths.profileSetup, (_) => const PlaceholderScreen('Set up your profile')),
      _route(AppPaths.events, (_) => const PlaceholderScreen('My events')),
      _route(AppPaths.eventSetup, (_) => const PlaceholderScreen('New event')),
      _route(
        AppPaths.eventHomePattern,
        (state) => PlaceholderScreen('Event', detail: state.pathParameters['id']),
      ),
      _route(
        AppPaths.vendors,
        (state) => PlaceholderScreen('Vendors', detail: state.uri.queryParameters['eventGroupId']),
      ),
      _route(
        AppPaths.vendorDetailPattern,
        (state) => PlaceholderScreen('Vendor', detail: state.pathParameters['id']),
      ),
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
      _route(AppPaths.vendorHome, (_) => const PlaceholderScreen('Vendor home')),
      _route(AppPaths.vendorProfile, (_) => const PlaceholderScreen('Vendor profile')),
      _route(AppPaths.vendorUnderReview, (_) => const PlaceholderScreen('Under review')),
      _route(AppPaths.vendorSuspended, (_) => const PlaceholderScreen('Suspended')),
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
