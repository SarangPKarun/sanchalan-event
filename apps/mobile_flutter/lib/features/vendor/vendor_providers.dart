import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vendor.dart';
import 'vendor_repository.dart';

Duration? _noRetry(int retryCount, Object error) => null;

/// The signed-in vendor's own profile. Port of apps/mobile/lib/vendor-context.tsx.
/// AsyncLoading = loading, AsyncError = retryable error.
class VendorDataNotifier extends AsyncNotifier<VendorMeResponse> {
  @override
  Future<VendorMeResponse> build() => ref.read(vendorRepositoryProvider).getMe();

  /// Full reload; flips to loading.
  Future<void> refetch() async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(ref.read(vendorRepositoryProvider).getMe);
    if (ref.mounted) state = result;
  }

  /// Reloads silently (no loading flip), keeping the current data if it fails.
  /// For pull-to-refresh.
  Future<void> reload() async {
    try {
      final fresh = await ref.read(vendorRepositoryProvider).getMe();
      if (ref.mounted) state = AsyncData(fresh);
    } catch (_) {
      // Keep what is shown; the next refresh retries.
    }
  }

  /// Replaces the vendor with a fresh server response without a loading flip.
  /// Use after any edit, submit or withdraw call.
  void apply(VendorMeResponse vendor) => state = AsyncData(vendor);
}

final vendorDataProvider = AsyncNotifierProvider<VendorDataNotifier, VendorMeResponse>(
  VendorDataNotifier.new,
  retry: _noRetry,
);

/// Published vendors for the organizer's directory, filtered.
final vendorsProvider = FutureProvider.autoDispose.family<List<Vendor>, VendorFilters>(
  (ref, filters) => ref.watch(vendorRepositoryProvider).listVendors(filters),
  retry: _noRetry,
);

final vendorDetailProvider = FutureProvider.autoDispose.family<Vendor, String>(
  (ref, id) => ref.watch(vendorRepositoryProvider).getVendor(id),
  retry: _noRetry,
);

final vendorCategoriesProvider = FutureProvider.autoDispose<List<VendorCategory>>(
  (ref) => ref.watch(vendorRepositoryProvider).listCategories(),
  retry: _noRetry,
);

/// The directory filters the organizer has chosen (kept while they move between tabs).
class VendorFiltersNotifier extends Notifier<VendorFilters> {
  @override
  VendorFilters build() => const VendorFilters();

  void set(VendorFilters filters) => state = filters;
}

final vendorFiltersProvider = NotifierProvider<VendorFiltersNotifier, VendorFilters>(VendorFiltersNotifier.new);
