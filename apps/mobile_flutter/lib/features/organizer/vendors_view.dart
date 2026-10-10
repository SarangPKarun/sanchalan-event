import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/enums.dart';
import '../../models/vendor.dart';
import '../../models/vendor_labels.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_retry.dart';
import '../../shared/widgets/skeleton.dart';
import '../vendor/vendor_repository.dart' show VendorFilters;
import 'home_view.dart' show HomeStatus;
import 'widgets/vendor_card.dart';

/// Vendors tab: filter chips and the list of published vendors. Plain widget;
/// the caller applies [filters] (on the server in the real app).
class VendorsView extends StatelessWidget {
  const VendorsView({
    super.key,
    required this.status,
    this.vendors = const [],
    this.filters = const VendorFilters(),
    this.categoryKeys = const [],
    this.forEventName,
    this.onFiltersChanged,
    this.onOpenVendor,
    this.onRetry,
    this.onRefresh,
  });

  final HomeStatus status;
  final List<Vendor> vendors;
  final VendorFilters filters;

  /// Categories offered as filter chips.
  final List<String> categoryKeys;

  /// Name of the event the organizer is shopping for, shown under the title.
  final String? forEventName;
  final ValueChanged<VendorFilters>? onFiltersChanged;
  final ValueChanged<Vendor>? onOpenVendor;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;

  bool get _filtered => filters.category != null || filters.priceTier != null;

  void _set({String? category, VendorPriceTier? tier, bool clearCategory = false, bool clearTier = false}) {
    onFiltersChanged?.call(VendorFilters(
      category: clearCategory ? null : (category ?? filters.category),
      priceTier: clearTier ? null : (tier ?? filters.priceTier),
      region: filters.region,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: forEventName == null ? kToolbarHeight : 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Vendors'),
            if (forEventName != null)
              Text('For $forEventName', style: text.bodySmall),
          ],
        ),
      ),
      body: Column(
        children: [
          _Filters(
            filters: filters,
            categoryKeys: categoryKeys,
            onCategory: (k) => _set(category: k, clearCategory: k == null),
            onTier: (t) => _set(tier: t, clearTier: t == null),
          ),
          Expanded(
            child: switch (status) {
              HomeStatus.loading => ListView(
                  padding: const EdgeInsets.all(AppSpace.gutter),
                  children: const [
                    SkeletonCard(height: 150),
                    SizedBox(height: AppSpace.m),
                    SkeletonCard(height: 150),
                    SizedBox(height: AppSpace.m),
                    SkeletonCard(height: 150),
                  ],
                ),
              HomeStatus.error => ErrorRetry(
                  message: 'Could not load vendors.',
                  onRetry: onRetry ?? () {},
                ),
              HomeStatus.ready when vendors.isEmpty => EmptyState(
                  icon: Icons.storefront_outlined,
                  title: _filtered ? 'No vendors match' : 'No vendors yet',
                  message: _filtered
                      ? 'Try a different category or price range.'
                      : 'Vendors appear here once they are approved. Check back soon.',
                  actionLabel: _filtered ? 'Clear filters' : null,
                  onAction: _filtered
                      ? () => onFiltersChanged?.call(VendorFilters(region: filters.region))
                      : null,
                ),
              HomeStatus.ready => _list(context),
            },
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s, AppSpace.gutter, AppSpace.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.m),
          child: Text(
            plural(vendors.length, 'vendor'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        for (final v in vendors)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.m),
            child: VendorCard(vendor: v, onTap: onOpenVendor == null ? null : () => onOpenVendor!(v)),
          ),
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filters,
    required this.categoryKeys,
    required this.onCategory,
    required this.onTier,
  });

  final VendorFilters filters;
  final List<String> categoryKeys;
  final ValueChanged<String?> onCategory;
  final ValueChanged<VendorPriceTier?> onTier;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> chips) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: Row(
            children: [for (final c in chips) Padding(padding: const EdgeInsets.only(right: AppSpace.s), child: c)],
          ),
        );
    return Column(
      children: [
        row([
          ChoiceChip(
            label: const Text('All categories'),
            selected: filters.category == null,
            showCheckmark: false,
            onSelected: (_) => onCategory(null),
          ),
          for (final k in categoryKeys)
            ChoiceChip(
              label: Text(categoryLabel(k)),
              selected: filters.category == k,
              showCheckmark: false,
              onSelected: (_) => onCategory(k),
            ),
        ]),
        const SizedBox(height: AppSpace.xs),
        row([
          ChoiceChip(
            label: const Text('Any price'),
            selected: filters.priceTier == null,
            showCheckmark: false,
            onSelected: (_) => onTier(null),
          ),
          for (final t in VendorPriceTier.values)
            ChoiceChip(
              label: Text(vendorPriceTierLabels[t]!),
              selected: filters.priceTier == t,
              showCheckmark: false,
              onSelected: (_) => onTier(t),
            ),
        ]),
      ],
    );
  }
}
