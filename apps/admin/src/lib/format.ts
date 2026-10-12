const STATUS_LABELS: Record<string, string> = {
  draft: "Draft",
  pending_review: "Pending review",
  published: "Published",
  rejected: "Rejected",
  suspended: "Suspended",
  pending: "Pending",
  approved: "Approved",
  merged: "Merged",
  active: "Active",
  disabled: "Disabled",
};

const ROLE_LABELS: Record<string, string> = {
  super_admin: "Super admin",
  vendor_reviewer: "Vendor reviewer",
  support: "Support",
};

const TIER_LABELS: Record<string, string> = {
  essential: "Essential",
  standard: "Standard",
  premium: "Premium",
  luxury: "Luxury",
};

const humanize = (v: string) => (v ? v[0]!.toUpperCase() + v.slice(1).replace(/_/g, " ") : v);

export const statusLabel = (s: string) => STATUS_LABELS[s] ?? humanize(s);
export const roleLabel = (r: string) => ROLE_LABELS[r] ?? humanize(r);
export const tierLabel = (t: string | null | undefined) => (t ? (TIER_LABELS[t] ?? humanize(t)) : "No tier");
export const formatDate = (iso: string | null | undefined) =>
  iso ? new Date(iso).toLocaleDateString("en-IN", { day: "numeric", month: "short", year: "numeric" }) : "";
export const formatDateTime = (iso: string) =>
  new Date(iso).toLocaleString("en-IN", { day: "numeric", month: "short", year: "numeric", hour: "numeric", minute: "2-digit" });
export const errorMessage = (err: unknown, fallback: string): string =>
  (err as { response?: { data?: { error?: string } } })?.response?.data?.error ?? fallback;
