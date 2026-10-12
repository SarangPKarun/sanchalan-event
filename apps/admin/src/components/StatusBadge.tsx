import { statusLabel } from "../lib/format.ts";

const TONES: Record<string, string> = {
  published: "success",
  approved: "success",
  active: "success",
  pending_review: "warn",
  pending: "warn",
  rejected: "danger",
  suspended: "danger",
  disabled: "danger",
};

export function StatusBadge({ status }: { status: string }) {
  return <span className={`badge badge-${TONES[status] ?? "neutral"}`}>{statusLabel(status)}</span>;
}
