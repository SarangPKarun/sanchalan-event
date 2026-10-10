/// Curated country list (port of apps/mobile/lib/countryCodes.ts): India first,
/// then the countries most likely to matter. Add more as real usage demands.
class Country {
  const Country(this.name, this.iso2, this.dialCode);

  final String name;
  final String iso2;

  /// With the leading plus, e.g. `+91`.
  final String dialCode;

  /// Regional-indicator trick, so no flag image assets are needed.
  String get flag => String.fromCharCodes(
    iso2.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65),
  );

  @override
  bool operator ==(Object other) => other is Country && other.iso2 == iso2;

  @override
  int get hashCode => iso2.hashCode;
}

const countries = <Country>[
  Country('India', 'IN', '+91'),
  Country('United States', 'US', '+1'),
  Country('United Kingdom', 'GB', '+44'),
  Country('United Arab Emirates', 'AE', '+971'),
  Country('Canada', 'CA', '+1'),
  Country('Australia', 'AU', '+61'),
  Country('Singapore', 'SG', '+65'),
  Country('Saudi Arabia', 'SA', '+966'),
  Country('Qatar', 'QA', '+974'),
  Country('Kuwait', 'KW', '+965'),
  Country('Oman', 'OM', '+968'),
  Country('Bahrain', 'BH', '+973'),
  Country('Malaysia', 'MY', '+60'),
  Country('New Zealand', 'NZ', '+64'),
  Country('Germany', 'DE', '+49'),
  Country('France', 'FR', '+33'),
  Country('Nepal', 'NP', '+977'),
  Country('Bangladesh', 'BD', '+880'),
  Country('Sri Lanka', 'LK', '+94'),
  Country('Pakistan', 'PK', '+92'),
  Country('South Africa', 'ZA', '+27'),
  Country('Kenya', 'KE', '+254'),
  Country('Japan', 'JP', '+81'),
  Country('Hong Kong', 'HK', '+852'),
  Country('Thailand', 'TH', '+66'),
  Country('Indonesia', 'ID', '+62'),
  Country('Philippines', 'PH', '+63'),
];

const defaultCountry = Country('India', 'IN', '+91');

/// Countries whose name or dial code contains [query] (blank matches all).
List<Country> searchCountries(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return countries;
  return [
    for (final c in countries)
      if (c.name.toLowerCase().contains(q) || c.dialCode.contains(q)) c,
  ];
}
