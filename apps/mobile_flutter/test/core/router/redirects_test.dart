import 'package:flutter_test/flutter_test.dart';
import 'package:sanchalan/core/router/guard_state.dart';
import 'package:sanchalan/core/router/paths.dart';
import 'package:sanchalan/core/router/redirects.dart';
import 'package:sanchalan/features/auth/auth_state.dart';
import 'package:sanchalan/models/enums.dart';

const loading = GuardState(auth: AuthState.loading());
const unauthed = GuardState(auth: AuthState.unauthed());
const admin = GuardState(auth: AuthState.authed(AuthRole.admin));

GuardState organizer(OrganizerPhase p) =>
    GuardState(auth: const AuthState.authed(AuthRole.organizer), organizer: p);
GuardState vendor(VendorPhase p) =>
    GuardState(auth: const AuthState.authed(AuthRole.vendor), vendor: p);

/// A sample of every kind of location.
final allPaths = [
  AppPaths.splash,
  AppPaths.unsupportedRole,
  AppPaths.phone,
  AppPaths.otp,
  AppPaths.profileSetup,
  AppPaths.events,
  AppPaths.eventSetup,
  AppPaths.eventHome('e1'),
  '${AppPaths.vendors}?eventGroupId=e1',
  AppPaths.vendorDetail('v1'),
  AppPaths.organizerLoading,
  AppPaths.organizerError,
  AppPaths.vendorHome,
  AppPaths.vendorProfile,
  AppPaths.vendorUnderReview,
  AppPaths.vendorSuspended,
  AppPaths.vendorLoading,
  AppPaths.vendorError,
  '/nowhere',
];

String settled(String location, GuardState g) => redirectFor(location, g) ?? location;

void main() {
  group('auth', () {
    test('while restoring the session everything goes to /splash', () {
      for (final p in allPaths) {
        expect(settled(p, loading), AppPaths.splash, reason: p);
      }
    });

    test('unauthed users only see phone and otp', () {
      expect(redirectFor(AppPaths.phone, unauthed), isNull);
      expect(redirectFor(AppPaths.otp, unauthed), isNull);
      for (final p in allPaths.where((p) => p != AppPaths.phone && p != AppPaths.otp)) {
        expect(redirectFor(p, unauthed), AppPaths.phone, reason: p);
      }
    });

    test('admin sessions land on the unsupported screen', () {
      for (final p in allPaths) {
        expect(settled(p, admin), AppPaths.unsupportedRole, reason: p);
      }
    });
  });

  group('organizer', () {
    test('loading and error screens', () {
      for (final p in allPaths) {
        expect(settled(p, organizer(OrganizerPhase.loading)), AppPaths.organizerLoading, reason: p);
        expect(settled(p, organizer(OrganizerPhase.error)), AppPaths.organizerError, reason: p);
      }
    });

    test('profile not filled in: only /profile-setup', () {
      for (final p in allPaths) {
        expect(settled(p, organizer(OrganizerPhase.needsProfile)), AppPaths.profileSetup, reason: p);
      }
    });

    test('ready: organizer screens allowed, everything else goes to /events', () {
      final g = organizer(OrganizerPhase.ready);
      for (final p in [
        AppPaths.events,
        AppPaths.eventSetup,
        AppPaths.eventHome('e1'),
        '${AppPaths.vendors}?eventGroupId=e1',
        AppPaths.vendors,
        AppPaths.vendorDetail('v1'),
      ]) {
        expect(redirectFor(p, g), isNull, reason: p);
      }
      for (final p in [
        AppPaths.splash,
        AppPaths.phone,
        AppPaths.otp,
        AppPaths.profileSetup,
        AppPaths.organizerLoading,
        AppPaths.organizerError,
        AppPaths.vendorHome,
        AppPaths.vendorProfile,
        AppPaths.unsupportedRole,
        '/nowhere',
      ]) {
        expect(redirectFor(p, g), AppPaths.events, reason: p);
      }
    });
  });

  group('vendor', () {
    test('loading and error screens', () {
      for (final p in allPaths) {
        expect(settled(p, vendor(VendorPhase.loading)), AppPaths.vendorLoading, reason: p);
        expect(settled(p, vendor(VendorPhase.error)), AppPaths.vendorError, reason: p);
      }
    });

    const expectedDefault = {
      VendorPhase.published: AppPaths.vendorHome,
      VendorPhase.pendingReview: AppPaths.vendorUnderReview,
      VendorPhase.suspended: AppPaths.vendorSuspended,
      VendorPhase.draft: AppPaths.vendorProfile,
      VendorPhase.rejected: AppPaths.vendorProfile,
    };

    for (final entry in expectedDefault.entries) {
      test('${entry.key.name}: lands on ${entry.value}', () {
        final g = vendor(entry.key);
        // From anywhere that is not allowed, the user ends up on the default.
        for (final p in allPaths.where((p) => !allowedVendorPaths(entry.key).contains(p))) {
          expect(settled(p, g), entry.value, reason: p);
        }
        expect(redirectFor(entry.value, g), isNull);
      });
    }

    test('a published vendor can open both home and the profile editor', () {
      final g = vendor(VendorPhase.published);
      expect(redirectFor(AppPaths.vendorHome, g), isNull);
      expect(redirectFor(AppPaths.vendorProfile, g), isNull);
    });

    test('other statuses are locked to a single screen', () {
      expect(redirectFor(AppPaths.vendorProfile, vendor(VendorPhase.pendingReview)),
          AppPaths.vendorUnderReview);
      expect(redirectFor(AppPaths.vendorHome, vendor(VendorPhase.draft)), AppPaths.vendorProfile);
      expect(redirectFor(AppPaths.vendorProfile, vendor(VendorPhase.suspended)),
          AppPaths.vendorSuspended);
      expect(redirectFor(AppPaths.vendorHome, vendor(VendorPhase.rejected)), AppPaths.vendorProfile);
    });

    test('organizer routes are not reachable by a vendor', () {
      for (final p in [AppPaths.events, AppPaths.eventSetup, AppPaths.vendors]) {
        expect(redirectFor(p, vendor(VendorPhase.published)), AppPaths.vendorHome, reason: p);
      }
    });
  });

  test('every state/path pair settles after one redirect (no loops)', () {
    final states = <GuardState>[
      loading,
      unauthed,
      admin,
      for (final p in OrganizerPhase.values) organizer(p),
      for (final p in VendorPhase.values) vendor(p),
    ];
    for (final g in states) {
      for (final p in allPaths) {
        final first = redirectFor(p, g);
        if (first != null) {
          expect(redirectFor(first, g), isNull, reason: '$g: $p -> $first is not stable');
        }
      }
    }
  });
}
