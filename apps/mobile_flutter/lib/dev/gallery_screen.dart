import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../models/enums.dart';
import '../shared/widgets/app_card.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/brand_mark.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/error_retry.dart';
import '../shared/widgets/primary_button.dart';
import '../shared/widgets/progress_ring.dart';
import '../shared/widgets/section_header.dart';
import '../shared/widgets/skeleton.dart';
import '../shared/widgets/status_chip.dart';

/// Debug-only page that shows every design token and widget in all its states.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Design gallery')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        children: [
          const SectionHeader('Brand'),
          const Wrap(
            spacing: AppSpace.xl,
            runSpacing: AppSpace.l,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BrandMark(size: 48),
              BrandMark(size: 72, wordmark: true),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Colors'),
          const _Swatches(),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Type'),
          for (final (name, style) in [
            ('Display / headlineLarge', text.headlineLarge),
            ('Headline / headlineSmall', text.headlineSmall),
            ('Title / titleLarge', text.titleLarge),
            ('Title / titleMedium', text.titleMedium),
            ('Body / bodyLarge', text.bodyLarge),
            ('Body / bodyMedium', text.bodyMedium),
            ('Caption / bodySmall', text.bodySmall),
            ('Label / labelLarge', text.labelLarge),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s),
              child: Text(name, style: style),
            ),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Buttons'),
          PrimaryButton(label: 'Primary action', onPressed: () {}),
          const SizedBox(height: AppSpace.s),
          PrimaryButton(label: 'With icon', icon: Icons.auto_awesome, onPressed: () {}),
          const SizedBox(height: AppSpace.s),
          PrimaryButton(label: 'Loading', loading: true, onPressed: () {}),
          const SizedBox(height: AppSpace.s),
          const PrimaryButton(label: 'Disabled', onPressed: null),
          const SizedBox(height: AppSpace.s),
          SecondaryButton(label: 'Secondary action', onPressed: () {}),
          const SizedBox(height: AppSpace.s),
          TextButton(onPressed: () {}, child: const Text('Text button')),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Status chips', actionLabel: 'See all'),
          Wrap(
            spacing: AppSpace.s,
            runSpacing: AppSpace.s,
            children: [
              for (final s in TaskStatus.values) StatusChip.task(s),
              for (final s in VendorStatus.values) StatusChip.vendor(s),
              const StatusChip(label: 'Info', tone: StatusTone.info),
              const StatusChip(label: 'Highlight', tone: StatusTone.primary),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Cards'),
          AppCard(
            onTap: () {},
            child: Row(
              children: [
                const ProgressRing(value: 0.62, child: Text('62%')),
                const SizedBox(width: AppSpace.l),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Priya & Rohan', style: text.titleMedium),
                      Text('48 days to go', style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.m),
          const AppCard(raised: false, child: Text('Flat card, no shadow')),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Inputs'),
          const AppTextField(label: 'Event name', hint: 'e.g. Priya & Rohan'),
          const SizedBox(height: AppSpace.l),
          const AppTextField(label: 'Phone number', errorText: 'Enter a valid Indian phone number.'),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Progress'),
          const Row(
            children: [
              ProgressRing(value: 0),
              SizedBox(width: AppSpace.l),
              ProgressRing(value: 0.35, size: 56, strokeWidth: 6),
              SizedBox(width: AppSpace.l),
              ProgressRing(value: 1, color: AppColors.successText, trackColor: AppColors.successBg),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Loading'),
          const Skeleton(height: 20, width: 180),
          const SizedBox(height: AppSpace.s),
          const SkeletonCard(),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Empty and error'),
          AppCard(
            raised: false,
            child: EmptyState(
              icon: Icons.celebration_outlined,
              title: 'Plan your first event',
              message: 'Tell us about the celebration and we will build your roadmap.',
              actionLabel: 'Create event',
              onAction: () {},
            ),
          ),
          const SizedBox(height: AppSpace.m),
          AppCard(raised: false, child: ErrorRetry(onRetry: () {})),
          const SizedBox(height: AppSpace.huge),
        ],
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches();

  @override
  Widget build(BuildContext context) {
    const swatches = <(String, Color, Color)>[
      ('primary', AppColors.primary, AppColors.onPrimary),
      ('primaryContainer', AppColors.primaryContainer, AppColors.onPrimaryContainer),
      ('maroon', AppColors.maroon, AppColors.onMaroon),
      ('maroonContainer', AppColors.maroonContainer, AppColors.maroon),
      ('gold', AppColors.gold, AppColors.ink),
      ('goldContainer', AppColors.goldContainer, AppColors.onGoldContainer),
      ('background', AppColors.background, AppColors.ink),
      ('surfaceMuted', AppColors.surfaceMuted, AppColors.ink),
      ('ink', AppColors.ink, AppColors.surface),
      ('inkMuted', AppColors.inkMuted, AppColors.surface),
      ('success', AppColors.successBg, AppColors.successText),
      ('warning', AppColors.warningBg, AppColors.warningText),
      ('error', AppColors.errorBg, AppColors.errorText),
      ('info', AppColors.infoBg, AppColors.infoText),
    ];
    return Wrap(
      spacing: AppSpace.s,
      runSpacing: AppSpace.s,
      children: [
        for (final (name, bg, fg) in swatches)
          Container(
            width: 104,
            height: 64,
            padding: const EdgeInsets.all(AppSpace.s),
            alignment: Alignment.bottomLeft,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(name, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg)),
          ),
      ],
    );
  }
}
