import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../models/enums.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/bottom_action_bar.dart';
import '../../shared/widgets/primary_button.dart';
import 'country_codes.dart';
import 'country_picker.dart';
import 'phone_validation.dart';

/// What the phone screen hands back when the user taps "Send code".
class PhoneEntry {
  const PhoneEntry({
    required this.phoneNumber,
    required this.role,
    required this.country,
  });

  /// E.164, e.g. `+919876543210`.
  final String phoneNumber;
  final AuthRole role;
  final Country country;
}

/// Role choice plus phone number. [onSubmit] does the work (sending the OTP) and
/// returns an error message to show, or null on success.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key, required this.onSubmit, this.onBack});

  final Future<String?> Function(PhoneEntry entry) onSubmit;
  final VoidCallback? onBack;

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _number = TextEditingController();
  Country _country = defaultCountry;
  AuthRole _role = AuthRole.organizer;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  PhoneCheck get _check => checkPhone(_country, _number.text);

  Future<void> _pickCountry() async {
    final picked = await showCountryPicker(context, selected: _country);
    if (picked != null && mounted) setState(() => _country = picked);
  }

  Future<void> _submit() async {
    final check = _check;
    if (!check.isValid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onSubmit(
      PhoneEntry(phoneNumber: check.e164, role: _role, country: _country),
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
    final check = _check;
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.xl,
                  AppSpace.s,
                  AppSpace.xl,
                  AppSpace.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Welcome!',
                        style: text.headlineLarge?.copyWith(
                          color: AppColors.maroon,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text('How will you use Sanchalan?', style: text.bodyLarge),
                    const SizedBox(height: AppSpace.l),
                    _RoleCard(
                      icon: Icons.celebration_outlined,
                      title: "I'm planning an event",
                      subtitle:
                          'Get a roadmap, track your budget and find vendors',
                      selected: _role == AuthRole.organizer,
                      onTap: () => setState(() => _role = AuthRole.organizer),
                    ),
                    const SizedBox(height: AppSpace.m),
                    _RoleCard(
                      icon: Icons.storefront_outlined,
                      title: "I'm a vendor",
                      subtitle:
                          'Get listed and reach families planning celebrations',
                      selected: _role == AuthRole.vendor,
                      onTap: () => setState(() => _role = AuthRole.vendor),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Text('Mobile number', style: text.titleSmall),
                    const SizedBox(height: AppSpace.s),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CountryButton(country: _country, onTap: _pickCountry),
                        const SizedBox(width: AppSpace.s),
                        Expanded(
                          child: TextField(
                            controller: _number,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [
                              AutofillHints.telephoneNumberNational,
                            ],
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9 ]'),
                              ),
                              LengthLimitingTextInputFormatter(15),
                            ],
                            style: text.bodyLarge,
                            onChanged: (_) => setState(() => _error = null),
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              hintText: '98765 43210',
                              errorText: check.showInvalidHint
                                  ? 'Enter a valid ${_country.name} mobile number.'
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text(
                      "We'll text you a 6-digit code to confirm it's you.",
                      style: text.bodySmall,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.l),
                      _ErrorBanner(_error!),
                    ],
                  ],
                ),
              ),
            ),
            BottomActionBar(
              children: [
                PrimaryButton(
                  label: 'Send code',
                  loading: _submitting,
                  onPressed: check.isValid ? _submit : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: AppCard(
        onTap: onTap,
        raised: selected,
        color: selected ? AppColors.primaryContainer : AppColors.surface,
        borderColor: selected ? AppColors.primary : AppColors.outline,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.surface
                    : AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpace.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.outlineStrong,
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryButton extends StatelessWidget {
  const _CountryButton({required this.country, required this.onTap});

  final Country country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Country code ${country.name} ${country.dialCode}. Tap to change.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.m),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.m),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(color: AppColors.outlineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: AppSpace.s),
              Text(
                country.dialCode,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Icon(
                Icons.expand_more,
                size: 20,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: AppColors.errorBg,
          borderRadius: BorderRadius.circular(AppRadius.m),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.errorText,
              size: 20,
            ),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.errorText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
