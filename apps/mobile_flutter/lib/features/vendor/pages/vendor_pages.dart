import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/link_launcher.dart';
import '../../../core/router/paths.dart';
import '../../../core/ui_feedback.dart';
import '../../../models/enums.dart';
import '../../../models/vendor.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/data_loading_screen.dart';
import '../../../shared/widgets/error_retry.dart';
import '../../auth/auth_controller.dart';
import '../../organizer/home_view.dart' show HomeStatus;
import '../sheets/past_work_sheet.dart';
import '../vendor_dashboard_view.dart';
import '../vendor_errors.dart';
import '../vendor_profile_editor_view.dart';
import '../vendor_profile_logic.dart';
import '../vendor_providers.dart';
import '../vendor_repository.dart';

/// The vendor's home, for every review status.
class VendorDashboardPage extends ConsumerStatefulWidget {
  const VendorDashboardPage({super.key});

  @override
  ConsumerState<VendorDashboardPage> createState() => _VendorDashboardPageState();
}

class _VendorDashboardPageState extends ConsumerState<VendorDashboardPage> {
  bool _busy = false;
  String? _error;

  Future<void> _withdraw() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final me = await ref.read(vendorRepositoryProvider).withdraw();
      ref.read(vendorDataProvider.notifier).apply(me);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e, 'Could not withdraw your profile.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _contactSupport() async {
    final launcher = ref.read(linkLauncherProvider);
    final ok = supportPhone.isNotEmpty ? await launcher.call(supportPhone) : await launcher.email(supportEmail);
    if (!ok && mounted) showToast(context, 'Could not open your phone or mail app. Contact us at $supportEmail.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(vendorDataProvider);
    final me = async.value;
    return VendorDashboardView(
      status: me != null
          ? HomeStatus.ready
          : async.hasError
              ? HomeStatus.error
              : HomeStatus.loading,
      me: me,
      busy: _busy,
      error: _error,
      onEdit: ([field]) => context.push(AppPaths.vendorProfile, extra: field),
      onWithdraw: _withdraw,
      onContactSupport: _contactSupport,
      onSignOut: () async {
        final yes = await showConfirmDialog(
          context,
          title: 'Sign out?',
          message: 'You will need your phone number and a new code to sign back in.',
          confirmLabel: 'Sign out',
          destructive: true,
        );
        if (yes) await ref.read(authControllerProvider.notifier).signOut();
      },
      onRetry: () => ref.read(vendorDataProvider.notifier).refetch(),
      onRefresh: () => ref.read(vendorDataProvider.notifier).reload(),
    );
  }
}

/// The profile editor connected to the backend.
class VendorEditorPage extends ConsumerWidget {
  const VendorEditorPage({super.key, this.focusField});

  final VendorRequiredField? focusField;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(vendorDataProvider).value;
    final categories = ref.watch(vendorCategoriesProvider);
    if (me == null) return const DataLoadingScreen();
    final keys = categories.value;
    if (keys == null) {
      return Scaffold(
        appBar: AppBar(),
        body: categories.hasError
            ? ErrorRetry(message: 'Could not load the categories.', onRetry: () => ref.invalidate(vendorCategoriesProvider))
            : const Center(child: CircularProgressIndicator()),
      );
    }

    final repo = ref.read(vendorRepositoryProvider);
    final data = ref.read(vendorDataProvider.notifier);

    void leaveIfLive(bool wasLive) {
      // A live profile has nothing more to do here once saved. If the save sent it back to review,
      // the router has already closed the editor.
      if (wasLive && context.mounted) context.canPop() ? context.pop() : context.go(AppPaths.vendorHome);
    }

    Future<String?> save(VendorProfileForm form) async {
      final wasLive = me.vendor.status == VendorStatus.published;
      try {
        var current = me;
        final body = diffProfile(current.vendor, form);
        if (!body.isEmpty) {
          final r = await repo.updateProfile(body);
          current = r.vendor;
          data.apply(current);
          if (r.reverificationTriggered) return null;
        }
        if (categoriesChanged(current.vendor, form.categoryKeys)) {
          final r = await repo.setCategories(form.categoryKeys);
          data.apply(r.vendor);
        }
      } catch (e) {
        return friendlyError(e, 'Could not save your changes.');
      }
      leaveIfLive(wasLive);
      return null;
    }

    return VendorProfileEditorView(
      me: me,
      categoryKeys: keys.map((c) => c.categoryKey).toList(),
      focusField: focusField,
      onBack: () => context.canPop() ? context.pop() : context.go(AppPaths.vendorHome),
      onSave: save,
      onSubmit: (form) async {
        // Save what was typed first, then send the profile for review.
        final wasLive = me.vendor.status == VendorStatus.published;
        final saveError = await save(form);
        if (saveError != null) return saveError;
        if (wasLive) return null; // closed by save
        try {
          data.apply(await repo.submit());
          return null;
        } catch (e) {
          final missing = missingFromError(e);
          if (missing.isNotEmpty) return stillNeededMessage(missing);
          return friendlyError(e, 'Could not submit your profile.');
        }
      },
      onSavePastWork: (PastWorkSaved entry, String? itemId) async {
        try {
          final body = PastWorkBody(title: entry.title, caption: entry.caption);
          final r = itemId == null ? await repo.addPastWork(body) : await repo.updatePastWork(itemId, body);
          data.apply(r.vendor);
          leaveIfLive(me.vendor.status == VendorStatus.published && !r.reverificationTriggered);
          return null;
        } catch (e) {
          return friendlyError(e, 'Could not save this entry.');
        }
      },
      onDeletePastWork: (itemId) async {
        try {
          final r = await repo.deletePastWork(itemId);
          data.apply(r.vendor);
          return null;
        } catch (e) {
          return friendlyError(e, 'Could not delete this entry.');
        }
      },
    );
  }
}
