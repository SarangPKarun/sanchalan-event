import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/enums.dart';

/// Small tinted pill that names a status. Color is never the only signal: the
/// label always says it.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = StatusTone.neutral, this.icon});

  final String label;
  final StatusTone tone;
  final IconData? icon;

  factory StatusChip.task(TaskStatus status, {Key? key}) {
    final (label, tone, icon) = switch (status) {
      TaskStatus.notStarted => ('Not started', StatusTone.neutral, Icons.radio_button_unchecked),
      TaskStatus.inProgress => ('In progress', StatusTone.info, Icons.timelapse),
      TaskStatus.done => ('Done', StatusTone.success, Icons.check_circle_outline),
      TaskStatus.overdue => ('Overdue', StatusTone.error, Icons.error_outline),
      TaskStatus.notApplicable => ('Removed', StatusTone.neutral, Icons.remove_circle_outline),
    };
    return StatusChip(key: key, label: label, tone: tone, icon: icon);
  }

  factory StatusChip.vendor(VendorStatus status, {Key? key}) {
    final (label, tone, icon) = switch (status) {
      VendorStatus.draft => ('Draft', StatusTone.neutral, Icons.edit_outlined),
      VendorStatus.pendingReview => ('In review', StatusTone.warning, Icons.hourglass_top),
      VendorStatus.published => ('Live', StatusTone.success, Icons.check_circle_outline),
      VendorStatus.rejected => ('Needs changes', StatusTone.error, Icons.error_outline),
      VendorStatus.suspended => ('Suspended', StatusTone.error, Icons.block),
    };
    return StatusChip(key: key, label: label, tone: tone, icon: icon);
  }

  factory StatusChip.proposal(CategoryProposalStatus status, {Key? key}) {
    final (label, tone, icon) = switch (status) {
      CategoryProposalStatus.pending => ('In review', StatusTone.warning, Icons.hourglass_top),
      CategoryProposalStatus.approved => ('Approved', StatusTone.success, Icons.check_circle_outline),
      CategoryProposalStatus.merged => ('Added as existing', StatusTone.success, Icons.check_circle_outline),
      CategoryProposalStatus.rejected => ('Not accepted', StatusTone.error, Icons.error_outline),
    };
    return StatusChip(key: key, label: label, tone: tone, icon: icon);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.m, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: tone.foreground), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
