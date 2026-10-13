import { describe, expect, it } from "vitest";
import { getEventTypeProfile, listEventTypeProfiles } from "../config/event-type-profiles.js";
import { validateEventDetails, validateEventDetailsForType } from "../services/event-profile.service.js";
import { AppError } from "../lib/errors.js";

const wedding = getEventTypeProfile("wedding");

describe("event type profiles", () => {
  it("falls back to the generic profile for an unknown type", () => {
    expect(getEventTypeProfile("bar_mitzvah").eventType).toBe("custom");
  });

  it("has unique question keys within each profile", () => {
    for (const p of listEventTypeProfiles()) {
      const keys = p.steps.flatMap((s) => s.questions.map((q) => q.key));
      expect(new Set(keys).size, p.eventType).toBe(keys.length);
    }
  });

  it("covers every core field in every profile", () => {
    for (const p of listEventTypeProfiles()) {
      const mapped = p.steps.flatMap((s) => s.questions.map((q) => q.mapsTo));
      for (const f of ["name", "region", "primaryDate", "guestCountEstimate", "totalBudget", "budgetTier"])
        expect(mapped, `${p.eventType} ${f}`).toContain(f);
    }
  });
});

describe("validateEventDetails", () => {
  it("accepts valid and missing optional answers", () => {
    expect(() => validateEventDetails(wedding, {}, undefined)).not.toThrow();
    expect(() =>
      validateEventDetails(wedding, {}, { community: "Iyer", subEventsWanted: ["haldi", "sangeet"], foodPreference: "veg" })
    ).not.toThrow();
  });

  it("rejects an unknown question key", () => {
    expect(() => validateEventDetails(wedding, {}, { nope: 1 })).toThrow(AppError);
  });

  it("rejects an option that is not allowed", () => {
    expect(() => validateEventDetails(wedding, {}, { foodPreference: "vegan" })).toThrow(AppError);
    expect(() => validateEventDetails(wedding, {}, { subEventsWanted: ["bachelor"] })).toThrow(AppError);
  });

  it("rejects a wrong value type", () => {
    expect(() => validateEventDetails(wedding, {}, { community: 5 })).toThrow(AppError);
  });

  it("requires required questions", () => {
    const corporate = getEventTypeProfile("corporate");
    expect(() => validateEventDetails(corporate, {}, {})).toThrow(/Invalid event details/);
    expect(() => validateEventDetails(corporate, {}, { corporateKind: "offsite" })).not.toThrow();
  });

  it("only asks showIf questions when their condition holds", () => {
    const profile = {
      eventType: "x",
      version: 1,
      steps: [
        {
          id: "s",
          title: "s",
          questions: [
            { key: "a", label: "a", kind: "single_select" as const, options: [{ value: "y", label: "y" }] },
            { key: "b", label: "b", kind: "text" as const, required: true, showIf: { key: "a", equals: "y" } },
          ],
        },
      ],
    };
    expect(() => validateEventDetails(profile, {}, {})).not.toThrow();
    expect(() => validateEventDetails(profile, {}, { a: "y" })).toThrow(AppError);
    expect(() => validateEventDetails(profile, {}, { a: "y", b: "ok" })).not.toThrow();
  });

  it("uses the generic profile for an unknown event type", () => {
    expect(() => validateEventDetailsForType("bar_mitzvah", {}, { description: "A party" })).not.toThrow();
  });
});
