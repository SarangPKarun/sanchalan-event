import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_state.dart';
import '../../features/organizer/organizer_providers.dart';
import '../../features/vendor/vendor_providers.dart';
import '../../models/enums.dart';

enum OrganizerPhase { loading, error, needsProfile, ready }

/// Where the signed-in vendor is: still loading, failed, or their review status.
enum VendorPhase {
  loading,
  error,
  draft,
  pendingReview,
  published,
  rejected,
  suspended;

  static VendorPhase fromStatus(VendorStatus s) => switch (s) {
        VendorStatus.draft => draft,
        VendorStatus.pendingReview => pendingReview,
        VendorStatus.published => published,
        VendorStatus.rejected => rejected,
        VendorStatus.suspended => suspended,
      };
}

/// Everything the redirect rules depend on, as one comparable value so the
/// router only refreshes when something that matters changes.
class GuardState {
  const GuardState({required this.auth, this.organizer, this.vendor});

  final AuthState auth;

  /// Set only while an organizer is signed in.
  final OrganizerPhase? organizer;

  /// Set only while a vendor is signed in.
  final VendorPhase? vendor;

  @override
  bool operator ==(Object other) =>
      other is GuardState &&
      other.auth == auth &&
      other.organizer == organizer &&
      other.vendor == vendor;

  @override
  int get hashCode => Object.hash(auth, organizer, vendor);

  @override
  String toString() => 'GuardState($auth, $organizer, $vendor)';
}

/// Watches the organizer or vendor data only for the signed-in role, so nothing
/// is fetched while signed out.
final guardStateProvider = Provider<GuardState>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthed) return GuardState(auth: auth);

  switch (auth.role!) {
    case AuthRole.organizer:
      final data = ref.watch(organizerDataProvider);
      final phase = data.hasError
          ? OrganizerPhase.error
          : switch (data.value) {
              OrganizerNeedsProfile() => OrganizerPhase.needsProfile,
              OrganizerReady() => OrganizerPhase.ready,
              null => OrganizerPhase.loading,
            };
      return GuardState(auth: auth, organizer: phase);
    case AuthRole.vendor:
      final data = ref.watch(vendorDataProvider);
      final phase = data.hasError
          ? VendorPhase.error
          : data.hasValue
              ? VendorPhase.fromStatus(data.value!.vendor.status)
              : VendorPhase.loading;
      return GuardState(auth: auth, vendor: phase);
    case AuthRole.admin:
      return GuardState(auth: auth);
  }
});
