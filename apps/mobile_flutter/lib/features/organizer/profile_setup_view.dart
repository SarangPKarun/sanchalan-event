import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/enums.dart';
import '../../models/organizer.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/bottom_action_bar.dart';
import '../../shared/widgets/primary_button.dart';

const _typeInfo = {
  OrganizerType.individual: (Icons.person_outline, 'Planning it myself'),
  OrganizerType.family: (Icons.family_restroom_outlined, 'For our family'),
  OrganizerType.company: (Icons.business_outlined, 'For a business'),
  OrganizerType.committee: (Icons.groups_outlined, 'For a group or society'),
};

/// One-time profile step after the first login: name and who is organizing.
class ProfileSetupView extends StatefulWidget {
  const ProfileSetupView({super.key, required this.onSubmit});

  final Future<String?> Function(UpdateOrganizerProfileBody body) onSubmit;

  @override
  State<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<ProfileSetupView> {
  final _name = TextEditingController();
  OrganizerType? _type;
  bool _showErrors = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _showErrors = true;
      _error = null;
    });
    if (_name.text.trim().isEmpty || _type == null) return;
    setState(() => _submitting = true);
    final error = await widget.onSubmit(
      UpdateOrganizerProfileBody(displayName: _name.text.trim(), organizerType: _type!),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xxl, AppSpace.xl, AppSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Tell us about you', style: text.headlineLarge?.copyWith(color: AppColors.maroon)),
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text('Just two quick things so we can personalise your plan.', style: text.bodyLarge),
                    const SizedBox(height: AppSpace.xl),
                    AppTextField(
                      label: 'Your name',
                      controller: _name,
                      hint: 'e.g. Priya Sharma',
                      errorText: _showErrors && _name.text.trim().isEmpty ? 'Please enter your name.' : null,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text('Who is organizing?', style: text.titleSmall),
                    const SizedBox(height: AppSpace.s),
                    for (final t in OrganizerType.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s),
                        child: Semantics(
                          button: true,
                          selected: _type == t,
                          inMutuallyExclusiveGroup: true,
                          label: '${organizerTypeLabel(t)}. ${_typeInfo[t]!.$2}',
                          excludeSemantics: true,
                          onTap: () => setState(() => _type = t),
                          child: AppCard(
                            raised: false,
                            onTap: () => setState(() => _type = t),
                            color: _type == t ? AppColors.primaryContainer : AppColors.surface,
                            borderColor: _type == t ? AppColors.primary : AppColors.outline,
                            child: Row(
                              children: [
                                Icon(_typeInfo[t]!.$1, color: AppColors.primary),
                                const SizedBox(width: AppSpace.l),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(organizerTypeLabel(t), style: text.titleMedium),
                                      Text(_typeInfo[t]!.$2, style: text.bodySmall),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _type == t ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  color: _type == t ? AppColors.primary : AppColors.outlineStrong,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_showErrors && _type == null)
                      Text('Choose one to continue.', style: text.bodySmall?.copyWith(color: AppColors.errorText)),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.m),
                      Text(_error!, style: text.bodyMedium?.copyWith(color: AppColors.errorText)),
                    ],
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [PrimaryButton(label: 'Continue', loading: _submitting, onPressed: _submit)],
            ),
          ],
        ),
      ),
    );
  }
}
