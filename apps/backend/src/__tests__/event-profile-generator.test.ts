import { describe, expect, it, vi } from "vitest";
import { validateGeneratedProfileOutput } from "../schemas/event-profile.schema.js";
import { generateEventProfile } from "../services/event-profile-generator.service.js";

const good = {
  steps: [
    {
      title: "About the crowd",
      questions: [
        {
          key: "chiefGuestType",
          label: "Who is the chief guest?",
          kind: "single_select",
          options: [
            { value: "minister", label: "Minister" },
            { value: "artist", label: "Artist" },
          ],
          allowOther: true,
        },
        { key: "stageNeeded", label: "How many speakers?", kind: "number" },
      ],
    },
  ],
};

describe("validateGeneratedProfileOutput", () => {
  it("accepts a good profile, even inside a code fence", () => {
    const r = validateGeneratedProfileOutput("```json\n" + JSON.stringify(good) + "\n```");
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.steps[0]!.id).toBe("gen1");
      expect(r.steps[0]!.questions.map((q) => q.key)).toEqual(["chiefGuestType", "stageNeeded"]);
    }
  });

  const bad = (mutate: (p: typeof good) => void) => {
    const copy = structuredClone(good);
    mutate(copy);
    return validateGeneratedProfileOutput(JSON.stringify(copy)).success;
  };

  it("rejects reserved or duplicate keys", () => {
    expect(bad((p) => (p.steps[0]!.questions[1]!.key = "name"))).toBe(false);
    expect(bad((p) => (p.steps[0]!.questions[1]!.key = "chiefGuestType"))).toBe(false);
  });

  it("rejects kinds the LLM may not use, and select questions without options", () => {
    expect(bad((p) => ((p.steps[0]!.questions[1] as { kind: string }).kind = "date"))).toBe(false);
    expect(bad((p) => delete (p.steps[0]!.questions[0] as { options?: unknown }).options)).toBe(false);
  });

  it("rejects too many questions and non-JSON", () => {
    expect(
      bad((p) => {
        p.steps = Array.from({ length: 3 }, (_, i) => ({
          title: `Step ${i}`,
          questions: Array.from({ length: 3 }, (_, j) => ({
            key: `question${i}${j}`,
            label: "Something to ask?",
            kind: "number" as const,
          })) as never,
        }));
      })
    ).toBe(false);
    expect(validateGeneratedProfileOutput("sorry, I cannot").success).toBe(false);
  });
});

describe("generateEventProfile", () => {
  it("retries once with the error, then falls back to the generic profile", async () => {
    const llm = vi.fn().mockResolvedValue({ text: "not json", usage: {} });
    const r = await generateEventProfile("org-fallback", "A kite festival for the neighbourhood", llm);
    expect(llm).toHaveBeenCalledTimes(2);
    expect(llm.mock.calls[1]![1]).toContain("previous response was invalid");
    expect(r.profileId).toBeNull();
    expect(r.profile.eventType).toBe("custom");
  });

  it("falls back when the LLM throws", async () => {
    const llm = vi.fn().mockRejectedValue(new Error("down"));
    const r = await generateEventProfile("org-down", "A kite festival for the neighbourhood", llm);
    expect(r.profileId).toBeNull();
  });

  it("rate limits an organizer", async () => {
    const llm = vi.fn().mockRejectedValue(new Error("down"));
    for (let i = 0; i < 6; i++) await generateEventProfile("org-limit", "A kite festival", llm);
    await expect(generateEventProfile("org-limit", "A kite festival", llm)).rejects.toMatchObject({ status: 429 });
  });
});
