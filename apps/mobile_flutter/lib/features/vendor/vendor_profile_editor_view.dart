import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/category_icons.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/enums.dart';
import '../../models/vendor.dart';
import '../../models/vendor_labels.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/bottom_action_bar.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/progress_ring.dart';
import '../../shared/widgets/status_chip.dart';
import 'sheets/past_work_sheet.dart';
import 'vendor_profile_logic.dart';
import 'widgets/notice_banner.dart';

const _reviewNotice =
    'Your profile will be hidden from families until our team approves it again. You can keep editing meanwhile.';

/// The vendor profile editor: one page in sections with a pinned action bar.
/// Plain widget: the callbacks do the work and return an error message or null.
class VendorProfileEditorView extends StatefulWidget {
  const VendorProfileEditorView({
    super.key,
    required this.me,
    required this.categoryKeys,
    required this.onSave,
    required this.onSubmit,
    required this.onSavePastWork,
    required this.onDeletePastWork,
    this.categoryLabels = const {},
    this.proposals = const [],
    this.onPropose,
    this.focusField,
    this.onBack,
  });

  /// The vendor as last saved on the server (past work is edited through its own calls).
  final VendorMeResponse me;

  /// Categories a vendor can choose from.
  final List<String> categoryKeys;

  /// Saves the profile fields without submitting (a draft, or changes to a live profile).
  final Future<String?> Function(VendorProfileForm form) onSave;

  /// Saves, then sends the profile for review.
  final Future<String?> Function(VendorProfileForm form) onSubmit;
  final Future<String?> Function(PastWorkSaved entry, String? itemId) onSavePastWork;
  final Future<String?> Function(String itemId) onDeletePastWork;

  /// Admin-set display names for categories added after launch, by key.
  final Map<String, String> categoryLabels;

  /// This vendor's own category suggestions.
  final List<CategoryProposal> proposals;

  /// Sends a new category suggestion; returns an error message or null. Null hides the option.
  final Future<String?> Function(String label, String? description)? onPropose;

  /// Scrolls to the section of this missing item when the editor opens.
  final VendorRequiredField? focusField;
  final VoidCallback? onBack;

  @override
  State<VendorProfileEditorView> createState() => _VendorProfileEditorViewState();
}

enum _Busy { save, submit }

class _VendorProfileEditorViewState extends State<VendorProfileEditorView> {
  late final VendorProfileForm _initial = VendorProfileForm.fromVendor(widget.me.vendor);
  late final _businessName = TextEditingController(text: _initial.businessName);
  late final _contact = TextEditingController(text: _initial.contactPersonName);
  late final _email = TextEditingController(text: _initial.email);
  late final _area = TextEditingController(text: _initial.serviceArea);
  late final _description = TextEditingController(text: _initial.description);
  late final _years = TextEditingController(text: _initial.years);
  late final _price = TextEditingController(text: _initial.startingPrice);
  late final _instagram = TextEditingController(text: _initial.instagramUrl);
  late final _website = TextEditingController(text: _initial.websiteUrl);
  late final _whatsapp = TextEditingController(text: _initial.whatsappNumber);
  late VendorPriceTier? _tier = _initial.priceTier;
  late List<String> _categories = [..._initial.categoryKeys];

  final _sections = {for (final f in VendorRequiredField.values) f: GlobalKey()};
  bool _showRequired = false;
  _Busy? _busy;
  String? _error;
  String? _notice;

  Vendor get _vendor => widget.me.vendor;
  bool get _published => _vendor.status == VendorStatus.published;
  int get _pastWorkCount => _vendor.portfolioItems.length;

  @override
  void initState() {
    super.initState();
    final field = widget.focusField;
    if (field != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(field));
    }
  }

  @override
  void dispose() {
    for (final c in [_businessName, _contact, _email, _area, _description, _years, _price, _instagram, _website, _whatsapp]) {
      c.dispose();
    }
    super.dispose();
  }

  void _scrollTo(VendorRequiredField f) {
    final context = _sections[f]!.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(context, duration: AppMotion.normal, alignment: 0.05);
    }
  }

  VendorProfileForm get _form => VendorProfileForm(
        businessName: _businessName.text,
        contactPersonName: _contact.text,
        email: _email.text,
        priceTier: _tier,
        serviceArea: _area.text,
        description: _description.text,
        years: _years.text,
        startingPrice: _price.text,
        instagramUrl: _instagram.text,
        websiteUrl: _website.text,
        whatsappNumber: _whatsapp.text,
        categoryKeys: _categories,
      );

  Map<String, String> get _errors => {
        ...validateFormats(_form),
        if (_showRequired) ...validateRequired(_form),
      };

  /// Live version of the server's completeness, from what is typed right now.
  List<VendorRequiredField> get _missing {
    final required = validateRequired(_form);
    return [
      if (required.containsKey('businessName')) VendorRequiredField.businessName,
      if (required.containsKey('contactPersonName')) VendorRequiredField.contactPersonName,
      if (required.containsKey('priceTier')) VendorRequiredField.priceTier,
      if (required.containsKey('serviceArea')) VendorRequiredField.serviceArea,
      if (required.containsKey('description')) VendorRequiredField.description,
      if (required.containsKey('categories')) VendorRequiredField.categories,
      if (_pastWorkCount == 0) VendorRequiredField.pastWork,
    ];
  }

  bool get _hasChanges => !diffProfile(_vendor, _form).isEmpty || categoriesChanged(_vendor, _categories);

  void _changed() => setState(() {
        _error = null;
        _notice = null;
      });

  Future<void> _save() async {
    if (validateFormats(_form).isNotEmpty) {
      setState(() => _error = 'Please fix the highlighted fields.');
      return;
    }
    if (triggersReview(_vendor, _form) &&
        !await showConfirmDialog(
          context,
          title: 'Send for review again?',
          message: _reviewNotice,
          confirmLabel: 'Save and send',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = _Busy.save;
      _error = null;
      _notice = null;
    });
    final error = await widget.onSave(_form);
    if (!mounted) return;
    setState(() {
      _busy = null;
      _error = error;
      _notice = error == null && !_published ? 'Draft saved.' : null;
    });
  }

  Future<void> _submit() async {
    setState(() => _showRequired = true);
    final problems = {...validateFormats(_form), ...validateRequired(_form)};
    if (problems.isNotEmpty) {
      setState(() => _error = 'Please fix the highlighted fields.');
      return;
    }
    if (_pastWorkCount == 0) {
      setState(() => _error = stillNeededMessage(const [VendorRequiredField.pastWork]));
      _scrollTo(VendorRequiredField.pastWork);
      return;
    }
    setState(() {
      _busy = _Busy.submit;
      _error = null;
      _notice = null;
    });
    final error = await widget.onSubmit(_form);
    if (!mounted) return;
    setState(() {
      _busy = null;
      _error = error;
    });
  }

  Future<void> _openPastWork([VendorPortfolioItem? item]) async {
    final result = await showPastWorkSheet(context, item: item);
    if (result == null || !mounted) return;
    if (_published &&
        !await showConfirmDialog(
          context,
          title: 'Send for review again?',
          message: _reviewNotice,
          confirmLabel: 'Save and send',
        )) {
      return;
    }
    if (!mounted) return;
    final error = switch (result) {
      PastWorkSaved() => await widget.onSavePastWork(result, item?.id),
      PastWorkDeleted() => await widget.onDeletePastWork(item!.id),
    };
    if (mounted) setState(() => _error = error);
  }

  void _toggleCategory(String key) => setState(() {
        _error = null;
        _notice = null;
        if (_categories.contains(key)) {
          _categories = [..._categories]..remove(key);
        } else if (_categories.length < vendorMaxCategories) {
          _categories = [..._categories, key];
        }
      });

  Future<void> _propose() async {
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => const _ProposeCategoryDialog(),
    );
    if (result == null || !mounted) return;
    final error = await widget.onPropose!(result.$1, result.$2);
    if (!mounted) return;
    setState(() {
      _error = error;
      _notice = error == null ? 'Sent for review. We will add it for everyone once approved.' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final errors = _errors;
    final setup = !_published;
    final missing = _missing;
    final descLen = _description.text.trim().length;
    final busy = _busy != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(setup ? 'Your business profile' : 'Edit profile'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.s, AppSpace.xl, AppSpace.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_vendor.status == VendorStatus.rejected) ...[
                    NoticeBanner(
                      tone: NoticeTone.error,
                      title: 'Changes requested',
                      message: _vendor.rejectionReason ?? 'Please review your profile and send it again.',
                    ),
                    const SizedBox(height: AppSpace.l),
                  ],
                  if (setup) ...[
                    _ProgressRow(done: 7 - missing.length, total: 7),
                    const SizedBox(height: AppSpace.xl),
                  ] else ...[
                    const NoticeBanner(
                      tone: NoticeTone.info,
                      title: 'Heads up',
                      message:
                          'Changing your business name, categories, price range, service area, about text or past work sends your profile back for review.',
                    ),
                    const SizedBox(height: AppSpace.xl),
                  ],

                  // --- Business ---
                  _Section(
                    key: _sections[VendorRequiredField.businessName],
                    title: 'Business',
                    children: [
                      AppTextField(
                        label: 'Business name',
                        controller: _businessName,
                        hint: 'e.g. Shubh Photos',
                        errorText: errors['businessName'],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _changed(),
                      ),
                      const SizedBox(height: AppSpace.l),
                      KeyedSubtree(
                        key: _sections[VendorRequiredField.contactPersonName],
                        child: AppTextField(
                          label: 'Contact person',
                          controller: _contact,
                          hint: 'Who should families ask for?',
                          errorText: errors['contactPersonName'],
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _changed(),
                        ),
                      ),
                    ],
                  ),

                  // --- What you offer ---
                  _Section(
                    key: _sections[VendorRequiredField.categories],
                    title: 'What you offer',
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Categories', style: text.titleSmall)),
                          Text('${_categories.length} of $vendorMaxCategories', style: text.bodySmall),
                        ],
                      ),
                      const SizedBox(height: AppSpace.s),
                      Wrap(
                        spacing: AppSpace.s,
                        runSpacing: AppSpace.s,
                        children: [
                          for (final k in widget.categoryKeys)
                            FilterChip(
                              avatar: Icon(categoryIcon(k), size: 18),
                              label: Text(widget.categoryLabels[k] ?? categoryLabel(k)),
                              selected: _categories.contains(k),
                              showCheckmark: false,
                              onSelected: _categories.contains(k) || _categories.length < vendorMaxCategories
                                  ? (_) => _toggleCategory(k)
                                  : null,
                            ),
                        ],
                      ),
                      if (errors['categories'] != null) _FieldError(errors['categories']!),
                      if (widget.onPropose != null) ...[
                        const SizedBox(height: AppSpace.s),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: const Text('Suggest a new category'),
                            onPressed: _propose,
                          ),
                        ),
                      ],
                      for (final p in widget.proposals)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(p.label, style: text.bodyMedium)),
                                  StatusChip.proposal(p.status),
                                ],
                              ),
                              if (p.status == CategoryProposalStatus.rejected && p.rejectionReason != null)
                                Text(p.rejectionReason!, style: text.bodySmall),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpace.l),
                      KeyedSubtree(
                        key: _sections[VendorRequiredField.priceTier],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Price range', style: text.titleSmall),
                            const SizedBox(height: AppSpace.s),
                            Wrap(
                              spacing: AppSpace.s,
                              runSpacing: AppSpace.s,
                              children: [
                                for (final t in VendorPriceTier.values)
                                  ChoiceChip(
                                    label: Text(vendorPriceTierLabels[t]!),
                                    selected: _tier == t,
                                    showCheckmark: false,
                                    onSelected: (_) => setState(() {
                                      _tier = t;
                                      _error = null;
                                      _notice = null;
                                    }),
                                  ),
                              ],
                            ),
                            if (errors['priceTier'] != null) _FieldError(errors['priceTier']!),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.l),
                      AppTextField(
                        label: 'Starting price (optional)',
                        controller: _price,
                        hint: '50,000',
                        keyboardType: TextInputType.number,
                        prefix: const Padding(
                          padding: EdgeInsets.only(left: AppSpace.l, right: AppSpace.s),
                          child: Text('₹'),
                        ),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
                        errorText: errors['startingPrice'],
                        onChanged: (_) => _changed(),
                      ),
                      const SizedBox(height: AppSpace.l),
                      AppTextField(
                        label: 'Years of experience (optional)',
                        controller: _years,
                        hint: '7',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        errorText: errors['yearsOfExperience'],
                        onChanged: (_) => _changed(),
                      ),
                    ],
                  ),

                  // --- Where ---
                  _Section(
                    key: _sections[VendorRequiredField.serviceArea],
                    title: 'Where you work',
                    children: [
                      AppTextField(
                        label: 'Service area',
                        controller: _area,
                        hint: 'e.g. Pune and Mumbai',
                        errorText: errors['serviceArea'],
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _changed(),
                      ),
                    ],
                  ),

                  // --- About ---
                  _Section(
                    key: _sections[VendorRequiredField.description],
                    title: 'About your business',
                    children: [
                      AppTextField(
                        label: 'Description',
                        controller: _description,
                        hint: 'What do you do, and what makes you different?',
                        maxLines: 5,
                        errorText: errors['description'],
                        helperText: descLen < vendorDescriptionMin
                            ? '${vendorDescriptionMin - descLen} more characters needed'
                            : '$descLen/$vendorDescriptionMax',
                        onChanged: (_) => _changed(),
                      ),
                    ],
                  ),

                  // --- Past work ---
                  _Section(
                    key: _sections[VendorRequiredField.pastWork],
                    title: 'Past work',
                    trailing: '$_pastWorkCount of $vendorMaxPastWork',
                    children: [
                      if (_vendor.portfolioItems.isEmpty)
                        Text(
                          'Add at least one example so families can see what you do.',
                          style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                        ),
                      for (final item in _vendor.portfolioItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpace.s),
                          child: AppCard(
                            raised: false,
                            onTap: () => _openPastWork(item),
                            semanticLabel: '${item.title}. Tap to edit.',
                            child: Row(
                              children: [
                                const Icon(Icons.collections_outlined, color: AppColors.primary),
                                const SizedBox(width: AppSpace.m),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.title, style: text.titleMedium),
                                      if (item.caption != null)
                                        Text(item.caption!, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.edit_outlined, size: 20, color: AppColors.inkMuted),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpace.s),
                      SecondaryButton(
                        label: _pastWorkCount >= vendorMaxPastWork ? 'Limit reached' : 'Add past work',
                        icon: Icons.add,
                        onPressed: _pastWorkCount >= vendorMaxPastWork ? null : () => _openPastWork(),
                      ),
                    ],
                  ),

                  // --- Links and contact ---
                  _Section(
                    title: 'Links and contact (optional)',
                    children: [
                      AppTextField(
                        label: 'Email',
                        controller: _email,
                        hint: 'name@business.in',
                        keyboardType: TextInputType.emailAddress,
                        errorText: errors['email'],
                        onChanged: (_) => _changed(),
                      ),
                      const SizedBox(height: AppSpace.l),
                      AppTextField(
                        label: 'WhatsApp number',
                        controller: _whatsapp,
                        hint: '+919876543210',
                        keyboardType: TextInputType.phone,
                        errorText: errors['whatsappNumber'],
                        onChanged: (_) => _changed(),
                      ),
                      const SizedBox(height: AppSpace.l),
                      AppTextField(
                        label: 'Instagram',
                        controller: _instagram,
                        hint: 'https://instagram.com/yourpage',
                        keyboardType: TextInputType.url,
                        errorText: errors['instagramUrl'],
                        onChanged: (_) => _changed(),
                      ),
                      const SizedBox(height: AppSpace.l),
                      AppTextField(
                        label: 'Website',
                        controller: _website,
                        hint: 'https://yourbusiness.in',
                        keyboardType: TextInputType.url,
                        errorText: errors['websiteUrl'],
                        onChanged: (_) => _changed(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          BottomActionBar(
            children: [
              if (_error != null) ...[
                NoticeBanner(tone: NoticeTone.error, title: _error!),
                const SizedBox(height: AppSpace.s),
              ],
              if (_notice != null) ...[
                NoticeBanner(tone: NoticeTone.success, title: _notice!),
                const SizedBox(height: AppSpace.s),
              ],
              if (setup) ...[
                PrimaryButton(
                  label: 'Submit for review',
                  icon: Icons.send_outlined,
                  loading: _busy == _Busy.submit,
                  onPressed: busy ? null : _submit,
                ),
                TextButton(
                  onPressed: busy ? null : _save,
                  child: Text(_busy == _Busy.save ? 'Saving...' : 'Save draft'),
                ),
              ] else
                PrimaryButton(
                  label: _hasChanges ? 'Save changes' : 'No changes yet',
                  loading: _busy == _Busy.save,
                  onPressed: busy || !_hasChanges ? null : _save,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.children, this.trailing});

  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(header: true, child: Text(title, style: text.titleLarge?.copyWith(color: AppColors.maroon))),
              ),
              if (trailing != null) Text(trailing!, style: text.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          ...children,
        ],
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppSpace.xs),
        child: Text(message, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.errorText)),
      );
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        ProgressRing(
          value: done / total,
          size: 44,
          strokeWidth: 5,
          color: done == total ? AppColors.successText : AppColors.primary,
          semanticLabel: '$done of $total steps done',
          child: Text('$done', style: text.labelMedium),
        ),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: Text(
            done == total ? 'Everything is filled in. Ready to submit.' : '$done of $total steps done',
            style: text.titleMedium,
          ),
        ),
      ],
    );
  }
}


class _ProposeCategoryDialog extends StatefulWidget {
  const _ProposeCategoryDialog();

  @override
  State<_ProposeCategoryDialog> createState() => _ProposeCategoryDialogState();
}

class _ProposeCategoryDialogState extends State<_ProposeCategoryDialog> {
  final _label = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _label.text.trim().length >= 3;
    return AlertDialog(
      title: const Text('Suggest a new category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            maxLength: 40,
            decoration: const InputDecoration(labelText: 'Category name', hintText: 'e.g. Mehendi artist'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: _description,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'What does it cover? (optional)'),
          ),
          const Text('Our team reviews it. Once approved, every vendor and family can use it.'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, (_label.text.trim(), _description.text.trim().isEmpty ? null : _description.text.trim()))
              : null,
          child: const Text('Send for review'),
        ),
      ],
    );
  }
}
