export const EVENT_TYPES = ["wedding", "birthday", "corporate", "religious", "engagement_only", "custom"] as const;
export type EventTypeKey = (typeof EVENT_TYPES)[number];
export const eventTypeLabel = (t: string) => (t === "engagement_only" ? "Engagement" : t[0]!.toUpperCase() + t.slice(1));
export const OWNER_TYPES = ["organizer", "vendor", "planner"] as const;
