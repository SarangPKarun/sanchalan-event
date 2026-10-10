import 'enums.dart';

/// Display labels for vendor category keys (VendorCategory has no label column).
/// Port of packages/shared-types/src/vendor-self.ts.
const vendorCategoryLabels = <String, String>{
  'venue': 'Venue',
  'catering': 'Catering',
  'decor': 'Décor',
  'photography': 'Photography',
  'attire': 'Attire',
  'invitations': 'Invitations',
  'music_entertainment': 'Music & Entertainment',
  'priest_officiant': 'Priest / Officiant',
  'transport': 'Transport',
  'misc': 'Other',
};

String vendorCategoryLabel(String categoryKey) {
  final known = vendorCategoryLabels[categoryKey];
  if (known != null) return known;
  final spaced = categoryKey.replaceAll('_', ' ');
  return spaced.isEmpty ? spaced : spaced[0].toUpperCase() + spaced.substring(1);
}

const vendorPriceTierLabels = <VendorPriceTier, String>{
  VendorPriceTier.essential: 'Essential',
  VendorPriceTier.standard: 'Standard',
  VendorPriceTier.premium: 'Premium',
  VendorPriceTier.luxury: 'Luxury',
};

const vendorMaxCategories = 5;
const vendorMaxPastWork = 10;
const vendorDescriptionMin = 30;
const vendorDescriptionMax = 1000;

/// Fields whose change on a published vendor sends the profile back to review.
const vendorReviewTriggerFields = ['businessName', 'serviceArea', 'priceTier', 'description'];
