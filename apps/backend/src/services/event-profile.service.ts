import { AppError } from "../lib/errors.js";
import {
  getEventTypeProfile,
  type EventTypeProfile,
  type Question,
} from "../config/event-type-profiles.js";

type Answers = Record<string, unknown>;

function isBlank(v: unknown): boolean {
  return v === undefined || v === null || v === "" || (Array.isArray(v) && v.length === 0);
}

function isVisible(q: Question, answers: Answers): boolean {
  return !q.showIf || answers[q.showIf.key] === q.showIf.equals;
}

function checkValue(q: Question, v: unknown): string | null {
  const allowed = q.options?.map((o) => o.value);
  switch (q.kind) {
    case "single_select":
      if (typeof v !== "string") return "must be a string";
      return allowed && !q.allowOther && !allowed.includes(v) ? "is not a valid option" : null;
    case "multi_select":
    case "chips":
      if (!Array.isArray(v) || v.some((x) => typeof x !== "string")) return "must be a list of strings";
      return allowed && !q.allowOther && v.some((x) => !allowed.includes(x)) ? "has an invalid option" : null;
    case "number":
    case "budget":
      return typeof v === "number" && Number.isFinite(v) ? null : "must be a number";
    default:
      return typeof v === "string" ? null : "must be a string";
  }
}

/** Validates the type-specific answers (EventGroup.details) against the profile for that event
 * type. `core` holds the top-level fields the client sent, so `showIf` and `required` can see
 * them. Questions with `mapsTo` are skipped here: createEventGroupSchema already validates them. */
export function validateEventDetails(
  profile: EventTypeProfile,
  core: Answers,
  details: Answers | undefined
): void {
  const given = details ?? {};
  const answers: Answers = { ...core, ...given };
  const questions = profile.steps.flatMap((s) => s.questions).filter((q) => !q.mapsTo);
  const known = new Set(questions.map((q) => q.key));

  const issues: string[] = [];
  for (const key of Object.keys(given)) {
    if (!known.has(key)) issues.push(`${key}: not a question for this event type`);
  }
  for (const q of questions) {
    if (!isVisible(q, answers)) continue;
    const v = given[q.key];
    if (isBlank(v)) {
      if (q.required) issues.push(`${q.key}: is required`);
      continue;
    }
    const problem = checkValue(q, v);
    if (problem) issues.push(`${q.key}: ${problem}`);
  }
  if (issues.length > 0) throw new AppError(400, "Invalid event details", { issues });
}

export function validateEventDetailsForType(
  eventType: string,
  core: Answers,
  details: Answers | undefined
): void {
  validateEventDetails(getEventTypeProfile(eventType), core, details);
}
