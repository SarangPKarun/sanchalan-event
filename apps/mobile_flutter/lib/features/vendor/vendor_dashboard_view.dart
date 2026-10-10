import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/enums.dart';
import '../../models/vendor.dart';
import '../../shared/widgets/bottom_action_bar.dart';
import '../../shared/widgets/brand_mark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_retry.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/skeleton.dart';
import '../../shared/widgets/status_chip.dart';
import '../organizer/home_view.dart' show HomeStatus;
import 'widgets/completeness_card.dart';
import 'widgets/notice_banner.dart';
import 'widgets/profile_preview_card.dart';
import 'widgets/status_timeline.dart';

/// The vendor's home: one screen whose content depends on the review status.
/// Plain widget; the router decides which status the vendor is in.
class VendorDashboardView extends StatelessWidget {
  const VendorDashboardView({
    super.key,
    required this.status,
    this.me,
    this.busy = false,
    this.error,
    this.onEdit,
    this.onWithdraw,
    this.onContactSupport,
    this.onSignOut,
    this.onRetry,
    this.onRefresh,
  });

  final HomeStatus status;
  final VendorMeResponse? me;

  /// A server call (withdraw) is running.
  final bool busy;

  /// Message from the last failed action.
  final String? error;

  /// Opens the editor; [field] is the missing item that was tapped, if any.
  final void Function([VendorRequiredField? field])? onEdit;
  final VoidCallback? onWithdraw;
  final VoidCallback? onContactSupport;
  final VoidCallback? onSignOut;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            BrandMark(size: 28),
            SizedBox(width: AppSpace.s),
            Flexible(child: Text('Sanchalan', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (_) => onSignOut?.call(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'signout',
                child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out')),
              ),
            ],
          ),
        ],
      ),
      body: switch (status) {
        HomeStatus.loading => const _Skeleton(),
        HomeStatus.error => ErrorRetry(onRetry: onRetry ?? () {}),
        HomeStatus.ready when me == null => const _Skeleton(),
        HomeStatus.ready => _Body(this, me!),
      },
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 32, width: 180),
          SizedBox(height: AppSpace.s),
          Skeleton(height: 26, width: 110, radius: 13),
          SizedBox(height: AppSpace.xl),
          SkeletonCard(height: 120),
          SizedBox(height: AppSpace.l),
          SkeletonCard(height: 260),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.view, this.me);

  final VendorDashboardView view;
  final VendorMeResponse me;

  Vendor get vendor => me.vendor;

  String get _greeting {
    final first = (vendor.contactPersonName ?? vendor.businessName)?.trim().split(' ').first;
    return first == null || first.isEmpty ? 'Hello' : 'Hello, $first';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = vendor.status;

    final content = <Widget>[
      Semantics(header: true, child: Text(_greeting, style: text.headlineLarge?.copyWith(color: AppColors.maroon))),
      const SizedBox(height: AppSpace.s),
      Align(alignment: Alignment.centerLeft, child: StatusChip.vendor(s)),
      const SizedBox(height: AppSpace.l),
      ...switch (s) {
        VendorStatus.draft || VendorStatus.rejected => _setup(context),
        VendorStatus.pendingReview => _pending(context),
        VendorStatus.published => _live(context),
        VendorStatus.suspended => const [],
      },
    ];

    if (s == VendorStatus.suspended) return _suspended(context);

    final scroll = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s, AppSpace.gutter, AppSpace.xxl),
      children: content,
    );
    final list = view.onRefresh == null ? scroll : RefreshIndicator(onRefresh: view.onRefresh!, child: scroll);

    final bar = switch (s) {
      VendorStatus.draft || VendorStatus.rejected => BottomActionBar(children: [
          PrimaryButton(
            label: s == VendorStatus.rejected
                ? 'Fix and resubmit'
                : me.completeness.complete
                    ? 'Review and submit'
                    : 'Continue setting up',
            icon: Icons.arrow_forward,
            onPressed: view.onEdit == null ? null : () => view.onEdit!(),
          ),
        ]),
      VendorStatus.published => BottomActionBar(children: [
          PrimaryButton(
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            onPressed: view.onEdit == null ? null : () => view.onEdit!(),
          ),
        ]),
      _ => null,
    };

    return Column(children: [Expanded(child: list), ?bar]);
  }

  List<Widget> _setup(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return [
      if (vendor.status == VendorStatus.rejected) ...[
        NoticeBanner(
          tone: NoticeTone.error,
          title: 'Changes requested',
          message: vendor.rejectionReason ?? 'Please review your profile and send it again.',
        ),
        const SizedBox(height: AppSpace.l),
      ],
      CompletenessCard(
        completeness: me.completeness,
        onTapItem: view.onEdit == null ? null : (f) => view.onEdit!(f),
      ),
      const SizedBox(height: AppSpace.l),
      Text(
        'Once our team approves your profile, families planning celebrations can find you.',
        style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
      ),
    ];
  }

  List<Widget> _pending(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final submitted = vendor.submittedAt;
    return [
      NoticeBanner(
        tone: NoticeTone.warning,
        title: 'Your profile is under review',
        message: '${vendor.businessName ?? 'Your business'} was submitted'
            '${submitted == null ? '' : ' on ${formatDate(submitted)}'}. '
            "We'll tell you here as soon as it is approved.",
      ),
      const SizedBox(height: AppSpace.xl),
      StatusTimeline(
        steps: [
          TimelineStep('Submitted', submitted == null ? 'Sent to our team' : formatDate(submitted), TimelineState.done),
          const TimelineStep('In review', 'Our team is checking your details', TimelineState.current),
          const TimelineStep('Live', 'Families can find and contact you', TimelineState.upcoming),
        ],
      ),
      const SizedBox(height: AppSpace.s),
      Text('Need to change something? Withdraw it, edit, and resubmit.',
          style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
      if (view.error != null) ...[
        const SizedBox(height: AppSpace.m),
        NoticeBanner(tone: NoticeTone.error, title: view.error!),
      ],
      const SizedBox(height: AppSpace.l),
      SecondaryButton(
        label: view.busy ? 'Withdrawing...' : 'Withdraw to edit',
        icon: Icons.undo,
        onPressed: view.busy ? null : view.onWithdraw,
      ),
    ];
  }

  List<Widget> _live(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return [
      const NoticeBanner(
        tone: NoticeTone.success,
        title: "You're live",
        message: 'Families planning events can find you in the vendor directory.',
      ),
      const SizedBox(height: AppSpace.xl),
      Text('How families see you', style: text.titleLarge),
      const SizedBox(height: AppSpace.s),
      ProfilePreviewCard(vendor: vendor),
      const SizedBox(height: AppSpace.l),
      const NoticeBanner(
        tone: NoticeTone.info,
        title: 'Good to know',
        message:
            'Changing your business name, categories, price range, service area, about text or past work sends your profile back for review.',
      ),
    ];
  }

  Widget _suspended(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpace.gutter, AppSpace.s, AppSpace.gutter, AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(_greeting, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: AppColors.maroon)),
          ),
          const SizedBox(height: AppSpace.s),
          StatusChip.vendor(VendorStatus.suspended),
          Expanded(
            child: EmptyState(
              icon: Icons.pause_circle_outline,
              title: 'Your listing is paused',
              message:
                  'Your profile is hidden from families while our team looks into it. Please contact Sanchalan support to sort this out.',
              actionLabel: 'Contact support',
              onAction: view.onContactSupport,
            ),
          ),
        ],
      ),
    );
  }
}
