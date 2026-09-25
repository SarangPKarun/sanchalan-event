export interface Country {
  name: string;
  iso2: string;
  dialCode: string;
}

// Curated list, not the full ISO-3166 set — covers India (this product's
// current market) plus the countries most likely to matter for NRI guests/
// vendors and other major markets. Add more as real usage demands it.
export const COUNTRIES: Country[] = [
  { name: "India", iso2: "IN", dialCode: "+91" },
  { name: "United States", iso2: "US", dialCode: "+1" },
  { name: "United Kingdom", iso2: "GB", dialCode: "+44" },
  { name: "United Arab Emirates", iso2: "AE", dialCode: "+971" },
  { name: "Canada", iso2: "CA", dialCode: "+1" },
  { name: "Australia", iso2: "AU", dialCode: "+61" },
  { name: "Singapore", iso2: "SG", dialCode: "+65" },
  { name: "Saudi Arabia", iso2: "SA", dialCode: "+966" },
  { name: "Qatar", iso2: "QA", dialCode: "+974" },
  { name: "Kuwait", iso2: "KW", dialCode: "+965" },
  { name: "Oman", iso2: "OM", dialCode: "+968" },
  { name: "Bahrain", iso2: "BH", dialCode: "+973" },
  { name: "Malaysia", iso2: "MY", dialCode: "+60" },
  { name: "New Zealand", iso2: "NZ", dialCode: "+64" },
  { name: "Germany", iso2: "DE", dialCode: "+49" },
  { name: "France", iso2: "FR", dialCode: "+33" },
  { name: "Nepal", iso2: "NP", dialCode: "+977" },
  { name: "Bangladesh", iso2: "BD", dialCode: "+880" },
  { name: "Sri Lanka", iso2: "LK", dialCode: "+94" },
  { name: "Pakistan", iso2: "PK", dialCode: "+92" },
  { name: "South Africa", iso2: "ZA", dialCode: "+27" },
  { name: "Kenya", iso2: "KE", dialCode: "+254" },
  { name: "Japan", iso2: "JP", dialCode: "+81" },
  { name: "Hong Kong", iso2: "HK", dialCode: "+852" },
  { name: "Thailand", iso2: "TH", dialCode: "+66" },
  { name: "Indonesia", iso2: "ID", dialCode: "+62" },
  { name: "Philippines", iso2: "PH", dialCode: "+63" },
];

export const DEFAULT_COUNTRY: Country = COUNTRIES[0]!; // India

/** Unicode regional-indicator trick — no flag image assets needed. */
export function flagEmoji(iso2: string): string {
  return iso2
    .toUpperCase()
    .replace(/./g, (c) => String.fromCodePoint(0x1f1e6 + c.charCodeAt(0) - 65));
}
