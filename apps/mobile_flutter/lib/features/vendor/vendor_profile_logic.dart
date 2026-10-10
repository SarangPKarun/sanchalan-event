import '../../models/enums.dart';
import '../../models/vendor.dart';
import '../../models/vendor_labels.dart';

/// Pure rules for the vendor profile: what is still missing, what changed, what
/// is valid. Ports of the RN profile screen and of the backend's rules
/// (apps/backend/src/schemas/vendor-self.schema.ts, services/vendor-self.service.ts).

// --- completeness ---

class ChecklistItem {
  const ChecklistItem({
    required this.field,
    required this.label,
    required this.hint,
    required this.done,
  });

  final VendorRequiredField field;
  final String label;
  final String hint;
  final bool done;
}

const _checklist = <VendorRequiredField, (String, String)>{
  VendorRequiredField.businessName: ('Business name', 'The name families will see'),
  VendorRequiredField.contactPersonName: ('Contact person', 'Who families should ask for'),
  VendorRequiredField.priceTier: ('Price range', 'From Essential to Luxury'),
  VendorRequiredField.serviceArea: ('Service area', 'The cities or regions you cover'),
  VendorRequiredField.description: ('About your business', 'At least $vendorDescriptionMin characters'),
  VendorRequiredField.categories: ('What you offer', 'Choose 1 to $vendorMaxCategories categories'),
  VendorRequiredField.pastWork: ('Past work', 'Add at least one example'),
};

/// Label used in "Still needed: ..." messages.
String missingFieldLabel(VendorRequiredField f) => _checklist[f]!.$1;

/// The seven things a profile needs, in the order the editor asks for them.
List<ChecklistItem> completenessItems(VendorCompleteness c) => [
      for (final f in VendorRequiredField.values)
        ChecklistItem(
          field: f,
          label: _checklist[f]!.$1,
          hint: _checklist[f]!.$2,
          done: !c.missing.contains(f),
        ),
    ];

int completenessPercent(VendorCompleteness c) {
  final total = VendorRequiredField.values.length;
  return ((total - c.missing.length) / total * 100).round();
}

/// "Still needed: Price range and Past work." (as shown after a failed submit).
String stillNeededMessage(Iterable<VendorRequiredField> missing) =>
    'Still needed: ${missing.map(missingFieldLabel).join(', ')}.';

/// Same rule the server applies, so previews and offline checks agree with it.
VendorCompleteness computeCompleteness(Vendor v) {
  final missing = <VendorRequiredField>[
    if (v.businessName?.trim().isEmpty ?? true) VendorRequiredField.businessName,
    if (v.contactPersonName?.trim().isEmpty ?? true) VendorRequiredField.contactPersonName,
    if (v.priceTier == null) VendorRequiredField.priceTier,
    if (v.serviceArea?.trim().isEmpty ?? true) VendorRequiredField.serviceArea,
    if ((v.description?.trim().length ?? 0) < vendorDescriptionMin) VendorRequiredField.description,
    if (v.vendorVendorCategories.isEmpty) VendorRequiredField.categories,
    if (v.portfolioItems.isEmpty) VendorRequiredField.pastWork,
  ];
  return VendorCompleteness(complete: missing.isEmpty, missing: missing);
}

// --- editing ---

/// What the user typed in the editor, as text (so blanks and bad input are visible).
class VendorProfileForm {
  const VendorProfileForm({
    this.businessName = '',
    this.contactPersonName = '',
    this.email = '',
    this.priceTier,
    this.serviceArea = '',
    this.description = '',
    this.years = '',
    this.startingPrice = '',
    this.instagramUrl = '',
    this.websiteUrl = '',
    this.whatsappNumber = '',
    this.categoryKeys = const [],
  });

  factory VendorProfileForm.fromVendor(Vendor v) => VendorProfileForm(
        businessName: v.businessName ?? '',
        contactPersonName: v.contactPersonName ?? '',
        email: v.email ?? '',
        priceTier: v.priceTier,
        serviceArea: v.serviceArea ?? '',
        description: v.description ?? '',
        years: v.yearsOfExperience?.toString() ?? '',
        startingPrice: v.startingPrice == null ? '' : v.startingPrice!.round().toString(),
        instagramUrl: v.instagramUrl ?? '',
        websiteUrl: v.websiteUrl ?? '',
        whatsappNumber: v.whatsappNumber ?? '',
        categoryKeys: v.categoryKeys,
      );

  final String businessName;
  final String contactPersonName;
  final String email;
  final VendorPriceTier? priceTier;
  final String serviceArea;
  final String description;
  final String years;
  final String startingPrice;
  final String instagramUrl;
  final String websiteUrl;
  final String whatsappNumber;
  final List<String> categoryKeys;
}

/// Digits only, or null when nothing numeric was typed ("₹ 50,000" -> 50000).
int? parseIntOrNull(String text) {
  final digits = text.replaceAll(RegExp(r'[^\d]'), '');
  return digits.isEmpty ? null : int.parse(digits);
}

String? _emptyToNull(String text) {
  final t = text.trim();
  return t.isEmpty ? null : t;
}

/// Only the fields that differ from the saved copy. Required text fields are
/// never blanked; optional ones can be cleared (sent as an explicit null).
UpdateVendorProfileBody diffProfile(Vendor saved, VendorProfileForm form) {
  String? changedText(String typed, String? current) {
    final t = typed.trim();
    return t.isNotEmpty && t != (current ?? '') ? t : null;
  }

  final clear = <String>{};
  String? optionalText(String name, String typed, String? current) {
    final next = _emptyToNull(typed);
    if (next == current) return null;
    if (next == null) clear.add(name);
    return next;
  }

  int? optionalInt(String name, String typed, num? current) {
    final next = parseIntOrNull(typed);
    final cur = current?.round();
    if (next == cur) return null;
    if (next == null) clear.add(name);
    return next;
  }

  return UpdateVendorProfileBody(
    businessName: changedText(form.businessName, saved.businessName),
    contactPersonName: changedText(form.contactPersonName, saved.contactPersonName),
    email: optionalText('email', form.email, saved.email),
    priceTier: form.priceTier != null && form.priceTier != saved.priceTier ? form.priceTier : null,
    serviceArea: changedText(form.serviceArea, saved.serviceArea),
    description: changedText(form.description, saved.description),
    yearsOfExperience: optionalInt('yearsOfExperience', form.years, saved.yearsOfExperience),
    startingPrice: optionalInt('startingPrice', form.startingPrice, saved.startingPrice),
    instagramUrl: optionalText('instagramUrl', form.instagramUrl, saved.instagramUrl),
    websiteUrl: optionalText('websiteUrl', form.websiteUrl, saved.websiteUrl),
    whatsappNumber: optionalText('whatsappNumber', form.whatsappNumber, saved.whatsappNumber),
    clear: clear,
  );
}

bool categoriesChanged(Vendor saved, List<String> keys) {
  final current = saved.categoryKeys;
  return keys.length != current.length || keys.any((k) => !current.contains(k));
}

/// Fields that send a published profile back to review when they change
/// (past work does too, but it is saved through its own calls).
const reviewTriggerFields = {'businessName', 'serviceArea', 'priceTier', 'description'};

bool triggersReview(Vendor saved, VendorProfileForm form) {
  if (saved.status != VendorStatus.published) return false;
  if (categoriesChanged(saved, form.categoryKeys)) return true;
  final body = diffProfile(saved, form).toJson();
  return reviewTriggerFields.any(body.containsKey);
}

// --- validation (messages are for the user; null means fine) ---

String? validateBusinessName(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Enter your business name.';
  if (t.length > 120) return 'Keep it under 120 characters.';
  return null;
}

String? validateContactPerson(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Enter a contact person.';
  if (t.length > 120) return 'Keep it under 120 characters.';
  return null;
}

String? validateServiceArea(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Enter the area you serve.';
  if (t.length > 200) return 'Keep it under 200 characters.';
  return null;
}

String? validateDescription(String v) {
  final n = v.trim().length;
  if (n < vendorDescriptionMin) return 'Write at least $vendorDescriptionMin characters (${vendorDescriptionMin - n} to go).';
  if (n > vendorDescriptionMax) return 'Keep it under $vendorDescriptionMax characters (${n - vendorDescriptionMax} too many).';
  return null;
}

String? validateEmail(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
  if (t.length > 200 || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Enter a valid email address.';
  return null;
}

String? validateWebUrl(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
  final uri = Uri.tryParse(t);
  final ok = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.contains('.') && t.length <= 300;
  return ok ? null : 'Enter a full link starting with http:// or https://';
}

String? validateWhatsapp(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(t) ? null : 'Use the international format, e.g. +919876543210';
}

String? validateYears(String v) {
  if (v.trim().isEmpty) return null;
  final n = parseIntOrNull(v);
  if (n == null || n > 80) return 'Enter years between 0 and 80.';
  return null;
}

String? validateStartingPrice(String v) {
  if (v.trim().isEmpty) return null;
  final n = parseIntOrNull(v);
  if (n == null || n > 100000000) return 'Enter an amount up to ₹10,00,00,000.';
  return null;
}

String? validateCategories(List<String> keys) {
  if (keys.isEmpty) return 'Choose at least one category.';
  if (keys.length > vendorMaxCategories) return 'Choose up to $vendorMaxCategories categories.';
  return null;
}

String? validatePastWorkTitle(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Give this work a title.';
  if (t.length > 150) return 'Keep the title under 150 characters.';
  return null;
}

String? validatePastWorkCaption(String v) => v.trim().length > 500 ? 'Keep it under 500 characters.' : null;

/// Every field's problem keyed by field name, for the formats that are always
/// checked (optional fields only when something is typed). Required-field
/// checks live in [validateRequired] and run on submit.
Map<String, String> validateFormats(VendorProfileForm f) => {
      if (f.businessName.trim().length > 120) 'businessName': validateBusinessName(f.businessName)!,
      if (f.contactPersonName.trim().length > 120) 'contactPersonName': validateContactPerson(f.contactPersonName)!,
      if (validateEmail(f.email) != null) 'email': validateEmail(f.email)!,
      if (f.serviceArea.trim().length > 200) 'serviceArea': validateServiceArea(f.serviceArea)!,
      if (f.description.trim().length > vendorDescriptionMax) 'description': validateDescription(f.description)!,
      if (validateYears(f.years) != null) 'yearsOfExperience': validateYears(f.years)!,
      if (validateStartingPrice(f.startingPrice) != null) 'startingPrice': validateStartingPrice(f.startingPrice)!,
      if (validateWebUrl(f.instagramUrl) != null) 'instagramUrl': validateWebUrl(f.instagramUrl)!,
      if (validateWebUrl(f.websiteUrl) != null) 'websiteUrl': validateWebUrl(f.websiteUrl)!,
      if (validateWhatsapp(f.whatsappNumber) != null) 'whatsappNumber': validateWhatsapp(f.whatsappNumber)!,
      if (f.categoryKeys.length > vendorMaxCategories) 'categories': validateCategories(f.categoryKeys)!,
    };

/// What is missing or too short for the profile to be submitted.
Map<String, String> validateRequired(VendorProfileForm f) => {
      if (validateBusinessName(f.businessName) != null) 'businessName': validateBusinessName(f.businessName)!,
      if (validateContactPerson(f.contactPersonName) != null) 'contactPersonName': validateContactPerson(f.contactPersonName)!,
      if (f.priceTier == null) 'priceTier': 'Choose a price range.',
      if (validateServiceArea(f.serviceArea) != null) 'serviceArea': validateServiceArea(f.serviceArea)!,
      if (validateDescription(f.description) != null) 'description': validateDescription(f.description)!,
      if (validateCategories(f.categoryKeys) != null) 'categories': validateCategories(f.categoryKeys)!,
    };
