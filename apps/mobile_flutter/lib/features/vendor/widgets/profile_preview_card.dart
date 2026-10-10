import 'package:flutter/material.dart';

import '../../../core/category_icons.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/vendor.dart';
import '../../../models/vendor_labels.dart';
import '../../../shared/widgets/app_card.dart';
import '../../organizer/widgets/vendor_card.dart' show VendorAvatar;

/// How families see this vendor: a compact version of the public profile.
class ProfilePreviewCard extends StatelessWidget {
  const ProfilePreviewCard({super.key, required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = vendor.businessName ?? 'Your business';
    final tier = vendor.priceTier == null ? null : vendorPriceTierLabels[vendor.priceTier!];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VendorAvatar(name: name, size: 56),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.titleLarge),
                    Text(
                      [if (tier != null) '$tier pricing', if (vendor.serviceArea != null) vendor.serviceArea!].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (vendor.categoryKeys.isNotEmpty) ...[
            const SizedBox(height: AppSpace.m),
            Wrap(
              spacing: AppSpace.m,
              runSpacing: AppSpace.xs,
              children: [
                for (final k in vendor.categoryKeys)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(categoryIcon(k), size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(categoryLabel(k), style: text.labelMedium?.copyWith(color: AppColors.ink)),
                    ],
                  ),
              ],
            ),
          ],
          if (vendor.description != null) ...[
            const SizedBox(height: AppSpace.m),
            Text(vendor.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
          ],
          if (vendor.startingPrice != null || vendor.yearsOfExperience != null) ...[
            const SizedBox(height: AppSpace.m),
            Wrap(
              spacing: AppSpace.l,
              children: [
                if (vendor.startingPrice != null)
                  Text('From ${formatInrCompact(vendor.startingPrice!)}', style: text.titleSmall),
                if (vendor.yearsOfExperience != null)
                  Text('${vendor.yearsOfExperience} yrs experience', style: text.bodyMedium),
              ],
            ),
          ],
          if (vendor.portfolioItems.isNotEmpty) ...[
            const SizedBox(height: AppSpace.l),
            Text('Past work', style: text.titleSmall),
            const SizedBox(height: AppSpace.xs),
            for (final item in vendor.portfolioItems.take(3))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.collections_outlined, size: 16, color: AppColors.inkMuted),
                    const SizedBox(width: AppSpace.s),
                    Expanded(child: Text(item.title, style: text.bodyMedium, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            if (vendor.portfolioItems.length > 3)
              Text('+${vendor.portfolioItems.length - 3} more', style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
