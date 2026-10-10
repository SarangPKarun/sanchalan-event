import 'package:flutter/material.dart';

import '../../../core/category_icons.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../models/vendor.dart';
import '../../../models/vendor_labels.dart';
import '../../../shared/widgets/app_card.dart';

/// Round avatar with the vendor's initial (there are no photos yet).
class VendorAvatar extends StatelessWidget {
  const VendorAvatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryContainer, AppColors.goldContainer],
          ),
        ),
        child: Text(
          initial,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.maroon,
                fontSize: size * 0.45,
              ),
        ),
      ),
    );
  }
}

/// One vendor in the directory.
class VendorCard extends StatelessWidget {
  const VendorCard({super.key, required this.vendor, this.onTap});

  final Vendor vendor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = vendor.businessName ?? 'Unnamed vendor';
    final keys = vendor.categoryKeys;
    final tier = vendor.priceTier == null ? null : vendorPriceTierLabels[vendor.priceTier!];

    return AppCard(
      onTap: onTap,
      semanticLabel:
          '$name. ${keys.map(categoryLabel).join(', ')}. ${vendor.serviceArea ?? ''}. ${vendor.startingPrice == null ? '' : 'From ${formatInr(vendor.startingPrice!)}.'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VendorAvatar(name: name),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (vendor.serviceArea != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.inkMuted),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(vendor.serviceArea!, style: text.bodySmall, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (tier != null) ...[
                const SizedBox(width: AppSpace.s),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldContainer,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(tier, style: text.labelSmall?.copyWith(color: AppColors.onGoldContainer)),
                ),
              ],
            ],
          ),
          if (keys.isNotEmpty) ...[
            const SizedBox(height: AppSpace.m),
            Wrap(
              spacing: AppSpace.s,
              runSpacing: AppSpace.xs,
              children: [
                for (final k in keys.take(3))
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(categoryIcon(k), size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(categoryLabel(k), style: text.labelMedium?.copyWith(color: AppColors.ink)),
                    ],
                  ),
                if (keys.length > 3) Text('+${keys.length - 3} more', style: text.labelMedium),
              ],
            ),
          ],
          if (vendor.description != null) ...[
            const SizedBox(height: AppSpace.s),
            Text(
              vendor.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpace.m),
          Row(
            children: [
              if (vendor.startingPrice != null)
                Text('From ${formatInrCompact(vendor.startingPrice!)}', style: text.titleSmall),
              if (vendor.yearsOfExperience != null) ...[
                const SizedBox(width: AppSpace.m),
                Expanded(
                  child: Text(
                    '${vendor.yearsOfExperience} yrs experience',
                    style: text.bodySmall,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
