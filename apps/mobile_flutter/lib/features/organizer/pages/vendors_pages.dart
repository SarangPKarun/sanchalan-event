import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/link_launcher.dart';
import '../../../core/router/paths.dart';
import '../../../core/ui_feedback.dart';
import '../../vendor/vendor_providers.dart';
import '../../vendor/vendor_repository.dart' show VendorFilters;
import '../home_view.dart' show HomeStatus;
import '../organizer_providers.dart';
import '../vendor_detail_view.dart';
import '../vendors_view.dart';
import 'home_page.dart' show pickFeatured;

/// Vendors tab: the directory with filters. [initialCategory] comes from
/// "Browse vendors" shortcuts (`/vendors?category=catering`).
class VendorsPage extends ConsumerStatefulWidget {
  const VendorsPage({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends ConsumerState<VendorsPage> {
  @override
  void initState() {
    super.initState();
    _applyCategory();
  }

  @override
  void didUpdateWidget(VendorsPage old) {
    super.didUpdateWidget(old);
    if (old.initialCategory != widget.initialCategory) _applyCategory();
  }

  void _applyCategory() {
    final category = widget.initialCategory;
    if (category == null) return;
    // Providers cannot change while the tree is building.
    Future.microtask(() {
      if (!mounted) return;
      final current = ref.read(vendorFiltersProvider);
      ref.read(vendorFiltersProvider.notifier).set(VendorFilters(category: category, priceTier: current.priceTier, region: current.region));
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(vendorFiltersProvider);
    final vendors = ref.watch(vendorsProvider(filters));
    final categories = ref.watch(vendorCategoriesProvider).value;
    final data = ref.watch(organizerDataProvider).value;
    final eventName = data is OrganizerReady
        ? pickFeatured(data.eventGroups, ref.watch(selectedEventIdProvider))?.name
        : null;

    return VendorsView(
      status: vendors.hasValue
          ? HomeStatus.ready
          : vendors.hasError
              ? HomeStatus.error
              : HomeStatus.loading,
      vendors: vendors.value ?? const [],
      filters: filters,
      categoryKeys: [for (final c in categories ?? const []) c.categoryKey],
      forEventName: eventName,
      onFiltersChanged: (f) => ref.read(vendorFiltersProvider.notifier).set(f),
      onOpenVendor: (v) => context.push(AppPaths.vendorDetail(v.id)),
      onRetry: () => ref.invalidate(vendorsProvider(filters)),
      onRefresh: () async {
        ref.invalidate(vendorsProvider(filters));
        try {
          await ref.read(vendorsProvider(filters).future);
        } catch (_) {
          // The error state is shown by the view.
        }
      },
    );
  }
}

/// One vendor's public profile, with Call, WhatsApp and links that open other apps.
class VendorDetailPage extends ConsumerWidget {
  const VendorDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(vendorDetailProvider(id));
    final vendor = detail.value;
    final launcher = ref.read(linkLauncherProvider);

    Future<void> open(Future<bool> Function() launch, String failure) async {
      if (!await launch() && context.mounted) showToast(context, failure);
    }

    return VendorDetailView(
      status: vendor != null
          ? HomeStatus.ready
          : detail.hasError
              ? HomeStatus.error
              : HomeStatus.loading,
      vendor: vendor,
      onRetry: () => ref.invalidate(vendorDetailProvider(id)),
      onCall: vendor == null ? null : () => open(() => launcher.call(vendor.phoneNumber), 'Could not open the phone app.'),
      onWhatsApp: vendor?.whatsappNumber == null
          ? null
          : () => open(() => launcher.whatsApp(vendor!.whatsappNumber!), 'Could not open WhatsApp.'),
      onOpenLink: (url) => open(() => launcher.openUrl(url), 'Could not open this link.'),
    );
  }
}
