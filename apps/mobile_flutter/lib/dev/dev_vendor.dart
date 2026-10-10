import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/organizer/home_view.dart' show HomeStatus;
import '../features/vendor/vendor_dashboard_view.dart';
import '../features/vendor/vendor_profile_editor_view.dart';
import '../features/vendor/vendor_profile_logic.dart';
import '../models/enums.dart';
import '../models/vendor.dart';
import '../models/vendor_labels.dart';
import '../shared/widgets/confirm_dialog.dart';
import 'dev_bar.dart';
import 'mock_data.dart';

final _mock = MockData();

enum DevVendorScenario {
  draft('Draft (2 of 7 done)'),
  rejected('Rejected'),
  underReview('Under review'),
  live('Live'),
  suspended('Suspended'),
  loading('Loading'),
  error('Error');

  const DevVendorScenario(this.label);
  final String label;
}

final devVendorScenario = ValueNotifier<DevVendorScenario>(DevVendorScenario.draft);

/// The vendor's profile as the preview edits it. Reset whenever the scenario changes.
final devVendorMe = ValueNotifier<VendorMeResponse>(_mock.vendorDraft);

VendorMeResponse _meFor(DevVendorScenario s) => switch (s) {
      DevVendorScenario.draft => _mock.vendorDraft,
      DevVendorScenario.rejected => _mock.vendorRejected,
      DevVendorScenario.underReview => _mock.vendorPending,
      DevVendorScenario.live => _mock.vendorPublished,
      DevVendorScenario.suspended => _mock.vendorSuspended,
      _ => _mock.vendorPublished,
    };

HomeStatus _statusFor(DevVendorScenario s) => switch (s) {
      DevVendorScenario.loading => HomeStatus.loading,
      DevVendorScenario.error => HomeStatus.error,
      _ => HomeStatus.ready,
    };

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$message (preview)')));
}

/// Leaves the editor: back if there is a screen below, else to the dashboard.
void _leave(BuildContext context) => context.canPop() ? context.pop() : context.go('/dev/v/home');

/// Applies the editor's fields to the mock vendor, like the server would.
VendorMeResponse _applyForm(VendorMeResponse me, VendorProfileForm f, {VendorStatus? status}) {
  final v = me.vendor;
  final json = v.toJson()
    ..['businessName'] = f.businessName.trim().isEmpty ? null : f.businessName.trim()
    ..['contactPersonName'] = f.contactPersonName.trim().isEmpty ? null : f.contactPersonName.trim()
    ..['email'] = f.email.trim().isEmpty ? null : f.email.trim()
    ..['priceTier'] = f.priceTier == null ? null : enumWireValue(f.priceTier!)
    ..['serviceArea'] = f.serviceArea.trim().isEmpty ? null : f.serviceArea.trim()
    ..['description'] = f.description.trim().isEmpty ? null : f.description.trim()
    ..['yearsOfExperience'] = parseIntOrNull(f.years)
    ..['startingPrice'] = parseIntOrNull(f.startingPrice)
    ..['instagramUrl'] = f.instagramUrl.trim().isEmpty ? null : f.instagramUrl.trim()
    ..['websiteUrl'] = f.websiteUrl.trim().isEmpty ? null : f.websiteUrl.trim()
    ..['whatsappNumber'] = f.whatsappNumber.trim().isEmpty ? null : f.whatsappNumber.trim()
    ..['vendorVendorCategories'] = [
      for (final k in f.categoryKeys)
        {
          'vendorId': v.id,
          'vendorCategoryId': 'vc-$k',
          'vendorCategory': {'id': 'vc-$k', 'categoryKey': k, 'applicableEventTypes': ['wedding']},
        },
    ]
    ..['status'] = enumWireValue(status ?? v.status);
  final vendor = Vendor.fromJson(json);
  return VendorMeResponse(vendor: vendor, completeness: computeCompleteness(vendor));
}

VendorMeResponse _withPastWork(VendorMeResponse me, List<Map<String, dynamic>> items, {VendorStatus? status}) {
  final json = me.vendor.toJson()
    ..['portfolioItems'] = items
    ..['status'] = enumWireValue(status ?? me.vendor.status);
  final vendor = Vendor.fromJson(json);
  return VendorMeResponse(vendor: vendor, completeness: computeCompleteness(vendor));
}

List<Map<String, dynamic>> _items(VendorMeResponse me) => [for (final i in me.vendor.portfolioItems) i.toJson()];

/// Vendor app preview: the dashboard for each status, and the editor.
class DevVendorHome extends StatefulWidget {
  const DevVendorHome({super.key});

  @override
  State<DevVendorHome> createState() => _DevVendorHomeState();
}

class _DevVendorHomeState extends State<DevVendorHome> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    devVendorScenario.addListener(_onScenario);
    devVendorMe.value = _meFor(devVendorScenario.value);
  }

  @override
  void dispose() {
    devVendorScenario.removeListener(_onScenario);
    super.dispose();
  }

  void _onScenario() {
    devVendorMe.value = _meFor(devVendorScenario.value);
    setState(() {
      _busy = false;
      _error = null;
    });
  }

  Future<void> _withdraw() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final me = devVendorMe.value;
    devVendorMe.value = VendorMeResponse(
      vendor: Vendor.fromJson({...me.vendor.toJson(), 'status': 'draft', 'submittedAt': null}),
      completeness: me.completeness,
    );
    setState(() => _busy = false);
    _toast(context, 'Withdrawn: back to draft');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DevBar<DevVendorScenario>(
          notifier: devVendorScenario,
          options: DevVendorScenario.values,
          labelOf: (s) => s.label,
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge([devVendorScenario, devVendorMe]),
            builder: (context, _) => VendorDashboardView(
              status: _statusFor(devVendorScenario.value),
              me: devVendorMe.value,
              busy: _busy,
              error: _error,
              onEdit: ([field]) => context.push('/dev/v/editor', extra: field),
              onWithdraw: _withdraw,
              onContactSupport: () => _toast(context, 'Contact support'),
              onSignOut: () async {
                final yes = await showConfirmDialog(
                  context,
                  title: 'Sign out?',
                  message: 'You will need your phone number and a new code to sign back in.',
                  confirmLabel: 'Sign out',
                  destructive: true,
                );
                if (yes && context.mounted) _toast(context, 'Signed out');
              },
              onRetry: () => devVendorScenario.value = DevVendorScenario.draft,
              onRefresh: () async => Future<void>.delayed(const Duration(milliseconds: 600)),
            ),
          ),
        ),
      ],
    );
  }
}

/// The editor wired to the shared mock vendor.
class DevVendorEditor extends StatelessWidget {
  const DevVendorEditor({super.key, this.focusField});

  final VendorRequiredField? focusField;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: devVendorMe,
      builder: (context, me, _) => VendorProfileEditorView(
        me: me,
        categoryKeys: vendorCategoryLabels.keys.toList(),
        focusField: focusField,
        onBack: () => context.canPop() ? context.pop() : context.go('/dev'),
        onSave: (form) async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          final reverify = triggersReview(me.vendor, form);
          devVendorMe.value = _applyForm(me, form, status: reverify ? VendorStatus.pendingReview : null);
          if (me.vendor.status == VendorStatus.published && context.mounted) {
            _toast(context, reverify ? 'Saved. Sent back for review' : 'Saved');
            _leave(context);
          }
          return null;
        },
        onSubmit: (form) async {
          await Future<void>.delayed(const Duration(seconds: 1));
          final applied = _applyForm(me, form);
          devVendorMe.value = applied;
          final missing = applied.completeness.missing;
          // Preview rule: an incomplete profile is refused with the server's list.
          if (missing.isNotEmpty) return stillNeededMessage(missing);
          devVendorMe.value = _applyForm(applied, form, status: VendorStatus.pendingReview);
          if (context.mounted) {
            _toast(context, 'Submitted for review');
            _leave(context);
          }
          return null;
        },
        onSavePastWork: (entry, itemId) async {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          final items = _items(me);
          if (itemId == null) {
            items.add({
              'id': 'pw-${items.length}-${DateTime.now().millisecondsSinceEpoch}',
              'vendorId': me.vendor.id,
              'title': entry.title,
              'mediaUrl': null,
              'caption': entry.caption,
              'displayOrder': items.length,
              'createdAt': DateTime.now().toIso8601String(),
            });
          } else {
            for (final i in items) {
              if (i['id'] == itemId) {
                i['title'] = entry.title;
                i['caption'] = entry.caption;
              }
            }
          }
          final reverify = me.vendor.status == VendorStatus.published;
          devVendorMe.value = _withPastWork(me, items, status: reverify ? VendorStatus.pendingReview : null);
          if (reverify && context.mounted) {
            _toast(context, 'Saved. Sent back for review');
            _leave(context);
          }
          return null;
        },
        onDeletePastWork: (itemId) async {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          final items = _items(me)..removeWhere((i) => i['id'] == itemId);
          final reverify = me.vendor.status == VendorStatus.published;
          devVendorMe.value = _withPastWork(me, items, status: reverify ? VendorStatus.pendingReview : null);
          if (reverify && context.mounted) {
            _toast(context, 'Saved. Sent back for review');
            _leave(context);
          }
          return null;
        },
      ),
    );
  }
}

List<RouteBase> devVendorRoutes() => [
      GoRoute(path: '/dev/v/home', builder: (_, _) => const DevVendorHome()),
      GoRoute(
        path: '/dev/v/editor',
        builder: (_, state) => DevVendorEditor(focusField: state.extra as VendorRequiredField?),
      ),
    ];
