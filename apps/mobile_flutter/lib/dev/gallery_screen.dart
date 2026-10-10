import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../features/organizer/event_stats.dart';
import '../features/organizer/widgets/budget_widgets.dart';
import '../features/organizer/widgets/event_card.dart';
import '../features/organizer/widgets/hero_card.dart';
import '../features/organizer/widgets/task_tile.dart';
import '../features/organizer/widgets/vendor_card.dart';
import '../features/vendor/widgets/completeness_card.dart';
import '../features/vendor/widgets/notice_banner.dart';
import '../features/vendor/widgets/profile_preview_card.dart';
import '../features/vendor/widgets/status_timeline.dart';
import '../models/enums.dart';
import 'mock_data.dart';
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
    final mock = MockData();
    final budget = budgetSummary(mock.wedding);
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
          const SectionHeader('Organizer: hero card'),
          HeroCard(
            event: mock.wedding,
            progress: taskProgress(mock.wedding.tasks, today: mock.today),
            today: mock.today,
            onTap: () {},
          ),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Organizer: tasks'),
          AppCard(
            raised: false,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.xs),
            child: Column(
              children: [
                for (final id in ['t1', 't5', 't3', 't2']) ...[
                  TaskTile(
                    task: mock.weddingTasks.firstWhere((t) => t.id == id),
                    today: mock.today,
                    showCategory: true,
                    onTap: () {},
                  ),
                  if (id != 't2') const Divider(),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Organizer: budget'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BudgetBar(summary: budget),
                const SizedBox(height: AppSpace.m),
                BudgetLegend(summary: budget),
                const SizedBox(height: AppSpace.s),
                RemainingLabel(summary: budget),
                const SizedBox(height: AppSpace.m),
                RemainingLabel(summary: budgetSummary(mock.birthday)),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Organizer: event cards'),
          EventCard(event: mock.wedding, today: mock.today, onTap: () {}),
          const SizedBox(height: AppSpace.m),
          EventCard(event: mock.birthday, today: mock.today, onTap: () {}),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Organizer: vendor card'),
          VendorCard(vendor: mock.vendors.first, onTap: () {}),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Vendor: profile completeness'),
          CompletenessCard(completeness: mock.vendorDraft.completeness, onTapItem: (_) {}),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Vendor: notices'),
          const NoticeBanner(tone: NoticeTone.success, title: "You're live", message: 'Families can find you.'),
          const SizedBox(height: AppSpace.s),
          const NoticeBanner(tone: NoticeTone.warning, title: 'Under review', message: 'We will tell you when it is approved.'),
          const SizedBox(height: AppSpace.s),
          const NoticeBanner(tone: NoticeTone.error, title: 'Changes requested', message: 'Please add a clearer description.'),
          const SizedBox(height: AppSpace.s),
          const NoticeBanner(tone: NoticeTone.info, title: 'Good to know', message: 'Changes may send you back for review.'),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Vendor: timeline'),
          const StatusTimeline(steps: [
            TimelineStep('Submitted', '8 Oct 2026', TimelineState.done),
            TimelineStep('In review', 'Our team is checking your details', TimelineState.current),
            TimelineStep('Live', 'Families can find and contact you', TimelineState.upcoming),
          ]),
          const SizedBox(height: AppSpace.xl),
          const SectionHeader('Vendor: public preview'),
          ProfilePreviewCard(vendor: mock.vendorPublished.vendor),
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
