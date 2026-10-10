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
  AppPaths.welcome,
  AppPaths.phone,
  AppPaths.otp,
  AppPaths.home,
  AppPaths.events,
  AppPaths.vendors,
  '${AppPaths.vendors}?category=catering',
  AppPaths.profile,
  AppPaths.profileSetup,
  AppPaths.profileEdit,
  AppPaths.eventSetup,
  AppPaths.eventHome('e1'),
  AppPaths.eventEdit('e1'),
  AppPaths.vendorDetail('v1'),
  AppPaths.organizerLoading,
  AppPaths.organizerError,
  AppPaths.vendorHome,
  AppPaths.vendorProfile,
  AppPaths.vendorLoading,
  AppPaths.vendorError,
  '/nowhere',
];

/// Where the user ends up from [location]: the redirect target, or [location] itself.
String settled(String location, GuardState g) => redirectFor(location, g) ?? location;

final organizerAppPaths = [
  AppPaths.home,
  AppPaths.events,
  AppPaths.vendors,
  '${AppPaths.vendors}?category=catering',
  AppPaths.profile,
  AppPaths.profileEdit,
  AppPaths.eventSetup,
  AppPaths.eventHome('e1'),
  AppPaths.eventEdit('e1'),
  AppPaths.vendorDetail('v1'),
];

void main() {
  group('auth', () {
    test('while restoring the session everything goes to /splash', () {
      for (final p in allPaths) {
        expect(settled(p, loading), AppPaths.splash, reason: p);
      }
    });

    test('unauthed users only see welcome, phone and otp', () {
      for (final p in [AppPaths.welcome, AppPaths.phone, AppPaths.otp]) {
        expect(redirectFor(p, unauthed), isNull, reason: p);
      }
      for (final p in allPaths.where((p) => ![AppPaths.welcome, AppPaths.phone, AppPaths.otp].contains(p))) {
        expect(redirectFor(p, unauthed), AppPaths.welcome, reason: p);
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

    test('ready: every organizer screen is allowed', () {
      for (final p in organizerAppPaths) {
        expect(redirectFor(p, organizer(OrganizerPhase.ready)), isNull, reason: p);
      }
    });

    test('ready: everything else goes to /home', () {
      final g = organizer(OrganizerPhase.ready);
      for (final p in allPaths.where((p) => !organizerAppPaths.contains(p))) {
        expect(redirectFor(p, g), AppPaths.home, reason: p);
      }
    });

    test('ready: the sign-in screens and profile setup are not reachable', () {
      final g = organizer(OrganizerPhase.ready);
      for (final p in [AppPaths.welcome, AppPaths.phone, AppPaths.otp, AppPaths.profileSetup, AppPaths.vendorHome]) {
        expect(redirectFor(p, g), AppPaths.home, reason: p);
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

    test('draft, rejected and published vendors may open the dashboard and the editor', () {
      for (final phase in [VendorPhase.draft, VendorPhase.rejected, VendorPhase.published]) {
        final g = vendor(phase);
        expect(redirectFor(AppPaths.vendorHome, g), isNull, reason: phase.name);
        expect(redirectFor(AppPaths.vendorProfile, g), isNull, reason: phase.name);
      }
    });

    test('pending and suspended vendors only see the dashboard', () {
      for (final phase in [VendorPhase.pendingReview, VendorPhase.suspended]) {
        final g = vendor(phase);
        expect(redirectFor(AppPaths.vendorHome, g), isNull, reason: phase.name);
        expect(redirectFor(AppPaths.vendorProfile, g), AppPaths.vendorHome, reason: phase.name);
      }
    });

    test('everything else leads to the dashboard, for every status', () {
      for (final phase in VendorPhase.values.where((p) => p != VendorPhase.loading && p != VendorPhase.error)) {
        final g = vendor(phase);
        for (final p in allPaths.where((p) => p != AppPaths.vendorHome && p != AppPaths.vendorProfile)) {
          expect(settled(p, g), AppPaths.vendorHome, reason: '${phase.name}: $p');
        }
      }
    });

    test('organizer screens are not reachable by a vendor', () {
      for (final p in organizerAppPaths) {
        expect(redirectFor(p, vendor(VendorPhase.published)), AppPaths.vendorHome, reason: p);
      }
    });

    test('a status change moves the vendor off a screen they may no longer open', () {
      // Published vendor editing, then sent back to review: the editor closes.
      expect(redirectFor(AppPaths.vendorProfile, vendor(VendorPhase.published)), isNull);
      expect(redirectFor(AppPaths.vendorProfile, vendor(VendorPhase.pendingReview)), AppPaths.vendorHome);
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

  group('debug design previews', () {
    test('/dev routes are open in debug builds, for every state', () {
      for (final g in [loading, unauthed, admin, organizer(OrganizerPhase.loading), vendor(VendorPhase.draft)]) {
        expect(redirectFor('/dev', g, allowDev: true), isNull);
        expect(redirectFor('/dev/gallery', g, allowDev: true), isNull);
      }
    });

    test('/dev routes are guarded like any other path in release builds', () {
      expect(redirectFor('/dev', unauthed, allowDev: false), AppPaths.welcome);
      expect(redirectFor('/dev/gallery', organizer(OrganizerPhase.ready), allowDev: false), AppPaths.home);
    });

    test('a path that only starts with the letters dev is not a preview', () {
      expect(redirectFor('/device', unauthed, allowDev: true), AppPaths.welcome);
    });
  });
}
