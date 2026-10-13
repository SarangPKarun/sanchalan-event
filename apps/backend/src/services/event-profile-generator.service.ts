import type { Prisma } from "@prisma/client";
import { prisma } from "../lib/prisma.js";
import { AppError } from "../lib/errors.js";
import { env } from "../lib/env.js";
import { RateLimiter } from "../lib/rate-limit.js";
import { generateCompletionDetailed, type LlmResult } from "../lib/llm.js";
import { buildCustomProfile, getEventTypeProfile, type EventTypeProfile } from "../config/event-type-profiles.js";
import { validateGeneratedProfileOutput } from "../schemas/event-profile.schema.js";

// Each call is an LLM call that costs money, so cap it per organizer.
const limiter = new RateLimiter(6, 60 * 60_000);

export function buildEventProfilePrompt(description: string) {
  const systemPrompt = [
    "You design the setup questions for an event-planning app used across India.",
    "A user is planning an event we have no ready-made form for. Given their one-line description,",
    "write the few extra questions that most change how this event should be planned, budgeted and staffed.",
    "",
    "Already asked separately, so do NOT ask about them: name, city or region, date, number of guests,",
    "total budget, budget style.",
    "",
    "Rules:",
    "- 1 to 3 steps, 1 to 3 questions per step, at most 8 questions in total. Fewer is better: ask only what matters.",
    "- Each question has kind single_select, multi_select, text or number.",
    "- single_select and multi_select need 2 to 8 options; option value is lowercase snake_case, label is short.",
    "  Set allowOther true when the list cannot be complete. text and number questions have no options.",
    "- key is a descriptive camelCase word (for example chiefGuestType, stageNeeded), unique across all questions.",
    "- Prefer tap-to-choose questions over typing. Mark required true only when the plan cannot be made without it.",
    "- Labels are plain, friendly questions addressed to the organizer.",
    "- Respond with STRICT JSON ONLY of the exact shape",
    '  { "steps": [ { "title": "About the crowd", "subtitle": "optional", "questions": [',
    '    { "key": "venueKind", "label": "What kind of venue?", "kind": "single_select",',
    '      "options": [ { "value": "hall", "label": "Hall" }, { "value": "outdoor", "label": "Outdoor" } ],',
    '      "allowOther": true, "required": false } ] } ] }.',
    "  No prose, no explanation, no markdown code fences.",
  ].join("\n");
  const userPrompt = JSON.stringify({ eventDescription: description });
  return { systemPrompt, userPrompt };
}

export interface GeneratedProfileResult {
  /** Null when the LLM failed and the generic profile is returned. */
  profileId: string | null;
  profile: EventTypeProfile;
}

/** Asks the LLM for the extra questions of an unknown event type. One retry with the validation
 * error fed back; if the LLM is down or keeps returning invalid output, returns the generic
 * profile so the user can still create the event. */
export async function generateEventProfile(
  organizerId: string,
  description: string,
  callLLM: (system: string, user: string) => Promise<LlmResult> = generateCompletionDetailed
): Promise<GeneratedProfileResult> {
  const wait = limiter.take(organizerId);
  if (wait > 0) {
    throw new AppError(429, `Too many requests. Try again in ${Math.ceil(wait / 60)} minute(s).`);
  }

  const { systemPrompt, userPrompt } = buildEventProfilePrompt(description);
  const started = Date.now();
  let inputTokens = 0;
  let outputTokens = 0;
  let lastError = "";

  for (let attempt = 0; attempt < 2; attempt++) {
    const prompt =
      attempt === 0
        ? userPrompt
        : `${userPrompt}\n\nYour previous response was invalid: ${lastError}\nFix it and return valid JSON only, matching the exact shape described in the system prompt.`;
    try {
      const { text, usage } = await callLLM(systemPrompt, prompt);
      inputTokens += usage.inputTokens ?? 0;
      outputTokens += usage.outputTokens ?? 0;
      const result = validateGeneratedProfileOutput(text);
      if (result.success) {
        const profile = buildCustomProfile(result.steps);
        const row = await prisma.generatedEventProfile.create({
          data: {
            organizerId,
            description,
            profile: profile as unknown as Prisma.InputJsonObject,
            llmModelUsed: env.LLM_MODEL,
            inputTokens,
            outputTokens,
            latencyMs: Date.now() - started,
          },
        });
        return { profileId: row.id, profile };
      }
      lastError = result.error;
    } catch (err) {
      lastError = err instanceof Error ? err.message : String(err);
    }
  }

  console.warn(`[event-profile] LLM failed, using the generic profile: ${lastError}`);
  return { profileId: null, profile: getEventTypeProfile("custom") };
}

/** The profile a `custom` event was created from, if the client says it used a generated one. */
export async function getGeneratedProfileForOrganizer(
  organizerId: string,
  profileId: string
): Promise<EventTypeProfile> {
  const row = await prisma.generatedEventProfile.findUnique({ where: { id: profileId } });
  if (!row || row.organizerId !== organizerId) throw new AppError(400, "Unknown generated profile");
  return row.profile as unknown as EventTypeProfile;
}
