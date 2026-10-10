import 'package:flutter/material.dart';

import '../../core/category_icons.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/vendor.dart';
import '../../models/vendor_labels.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/bottom_action_bar.dart';
import '../../shared/widgets/error_retry.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/skeleton.dart';
import 'home_view.dart' show HomeStatus;
import 'widgets/vendor_card.dart';

/// Read-only profile of a vendor with Call and WhatsApp pinned at the bottom.
class VendorDetailView extends StatelessWidget {
  const VendorDetailView({
    super.key,
    required this.status,
    this.vendor,
    this.onCall,
    this.onWhatsApp,
    this.onOpenLink,
    this.onRetry,
  });

  final HomeStatus status;
  final Vendor? vendor;
  final VoidCallback? onCall;
  final VoidCallback? onWhatsApp;
  final ValueChanged<String>? onOpenLink;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final v = vendor;
    if (status == HomeStatus.loading || (status == HomeStatus.ready && v == null)) {
      return Scaffold(
        appBar: AppBar(),
        body: const Padding(
          padding: EdgeInsets.all(AppSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(height: 72, width: 72, radius: 36),
              SizedBox(height: AppSpace.l),
              Skeleton(height: 28, width: 220),
              SizedBox(height: AppSpace.xl),
              SkeletonCard(height: 120),
            ],
          ),
        ),
      );
    }
    if (status == HomeStatus.error) {
      return Scaffold(appBar: AppBar(), body: ErrorRetry(message: 'Could not load this vendor.', onRetry: onRetry ?? () {}));
    }

    final text = Theme.of(context).textTheme;
    final name = v!.businessName ?? 'Unnamed vendor';
    final facts = <(IconData, String, String)>[
      if (v.yearsOfExperience != null) (Icons.workspace_premium_outlined, 'Experience', '${v.yearsOfExperience} years'),
      if (v.startingPrice != null) (Icons.sell_outlined, 'Starting price', formatInr(v.startingPrice!)),
      if (v.serviceArea != null) (Icons.location_on_outlined, 'Service area', v.serviceArea!),
      if (v.contactPersonName != null) (Icons.person_outline, 'Contact person', v.contactPersonName!),
    ];

    return Scaffold(
      appBar: AppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VendorAvatar(name: name, size: 72),
                      const SizedBox(width: AppSpace.l),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(header: true, child: Text(name, style: text.headlineMedium)),
                            if (v.priceTier != null)
                              Text('${vendorPriceTierLabels[v.priceTier!]} pricing', style: text.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.l),
                  Wrap(
                    spacing: AppSpace.s,
                    runSpacing: AppSpace.s,
                    children: [
                      for (final k in v.categoryKeys)
                        Chip(
                          avatar: Icon(categoryIcon(k), size: 16, color: AppColors.primary),
                          label: Text(categoryLabel(k)),
                          backgroundColor: AppColors.primaryContainer,
                          side: BorderSide.none,
                        ),
                    ],
                  ),
                  if (v.description != null) ...[
                    const SizedBox(height: AppSpace.l),
                    Text(v.description!, style: text.bodyLarge),
                  ],
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xl),
                    AppCard(
                      raised: false,
                      child: Column(
                        children: [
                          for (var i = 0; i < facts.length; i++) ...[
                            if (i > 0) const Divider(height: AppSpace.xl),
                            Row(
                              children: [
                                Icon(facts[i].$1, color: AppColors.maroon, size: 22),
                                const SizedBox(width: AppSpace.m),
                                Expanded(child: Text(facts[i].$2, style: text.bodyMedium)),
                                Flexible(
                                  child: Text(
                                    facts[i].$3,
                                    style: text.titleSmall,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (v.portfolioItems.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xl),
                    const SectionHeader('Past work'),
                    for (final item in v.portfolioItems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s),
                        child: AppCard(
                          raised: false,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.collections_outlined, color: AppColors.primary),
                              const SizedBox(width: AppSpace.m),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.title, style: text.titleMedium),
                                    if (item.caption != null)
                                      Text(item.caption!, style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (v.instagramUrl != null || v.websiteUrl != null) ...[
                    const SizedBox(height: AppSpace.l),
                    const SectionHeader('Links'),
                    if (v.instagramUrl != null)
                      _LinkTile(icon: Icons.camera_alt_outlined, label: 'Instagram', onTap: onOpenLink == null ? null : () => onOpenLink!(v.instagramUrl!)),
                    if (v.websiteUrl != null)
                      _LinkTile(icon: Icons.language, label: 'Website', onTap: onOpenLink == null ? null : () => onOpenLink!(v.websiteUrl!)),
                  ],
                ],
              ),
            ),
          ),
          BottomActionBar(
            children: [
              Row(
                children: [
                  Expanded(child: PrimaryButton(label: 'Call', icon: Icons.call_outlined, onPressed: onCall)),
                  if (v.whatsappNumber != null) ...[
                    const SizedBox(width: AppSpace.m),
                    Expanded(child: SecondaryButton(label: 'WhatsApp', icon: Icons.chat_outlined, onPressed: onWhatsApp)),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: kMinTouchTarget,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary)),
      trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.inkMuted),
      onTap: onTap,
    );
  }
}
