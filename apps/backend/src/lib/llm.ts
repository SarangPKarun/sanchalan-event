import { env } from "./env.js";

export interface LlmUsage {
  inputTokens?: number | undefined;
  outputTokens?: number | undefined;
}
export interface LlmResult {
  text: string;
  usage: LlmUsage;
}

/** Same call as generateCompletion, plus the token usage the provider reported. */
export async function generateCompletionDetailed(systemPrompt: string, userPrompt: string): Promise<LlmResult> {
  switch (env.LLM_PROVIDER) {
    case "anthropic":
      return callAnthropic(systemPrompt, userPrompt);
    case "openai":
      return callOpenAI(systemPrompt, userPrompt);
    case "groq":
      return callOpenAI(systemPrompt, userPrompt, "https://api.groq.com/openai/v1/chat/completions", "Groq");
    case "google":
      return callGemini(systemPrompt, userPrompt);
  }
}

export async function generateCompletion(systemPrompt: string, userPrompt: string): Promise<string> {
  return (await generateCompletionDetailed(systemPrompt, userPrompt)).text;
}

interface AnthropicContentBlock {
  type: string;
  text?: string;
}

async function callAnthropic(system: string, user: string): Promise<LlmResult> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": env.LLM_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: env.LLM_MODEL,
      // Headroom for models with thinking on by default (their thinking
      // tokens count against this budget before the actual text block).
      max_tokens: 8000,
      system,
      messages: [{ role: "user", content: user }],
    }),
  });
  if (!res.ok) {
    throw new Error(`Anthropic call failed: ${res.status} ${await res.text()}`);
  }
  const data = (await res.json()) as Record<string, any>;
  if (data.stop_reason === "max_tokens") {
    throw new Error("Anthropic response truncated at max_tokens.");
  }
  // Don't index content[0] directly — models with thinking on by default can
  // return a `thinking` block before the `text` block.
  const textBlock = (data.content as AnthropicContentBlock[]).find((b) => b.type === "text");
  if (!textBlock?.text) {
    throw new Error("Anthropic response had no text block.");
  }
  return { text: textBlock.text, usage: { inputTokens: data.usage?.input_tokens, outputTokens: data.usage?.output_tokens } };
}

// Targets chat-completions-family models (gpt-4o-style). A newer
// reasoning-tier LLM_MODEL may not accept `response_format`/plain
// `role: "system"` the same way — this adapter isn't guaranteed uniform
// across every OpenAI model id.
async function callOpenAI(
  system: string,
  user: string,
  url = "https://api.openai.com/v1/chat/completions",
  label = "OpenAI",
): Promise<LlmResult> {
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.LLM_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: env.LLM_MODEL,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
      // Requires the model's response to be a JSON *object* at the root —
      // this is why the roadmap wire contract is {"tasks": [...]}, not a bare array.
      response_format: { type: "json_object" },
    }),
  });
  if (!res.ok) {
    throw new Error(`${label} call failed: ${res.status} ${await res.text()}`);
  }
  const data = (await res.json()) as Record<string, any>;
  if (data.choices[0].finish_reason === "length") {
    throw new Error(`${label} response truncated.`);
  }
  const text = data.choices[0].message.content;
  if (!text) {
    throw new Error(`${label} response had no content.`);
  }
  return { text, usage: { inputTokens: data.usage?.prompt_tokens, outputTokens: data.usage?.completion_tokens } };
}

async function callGemini(system: string, user: string): Promise<LlmResult> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${env.LLM_MODEL}:generateContent?key=${env.LLM_API_KEY}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      // camelCase — NOT system_instruction. The snake_case field name is
      // silently ignored by the API (unknown field, not an error), which
      // would drop the system prompt with no visible failure.
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: user }] }],
      generationConfig: { responseMimeType: "application/json" },
    }),
  });
  if (!res.ok) {
    throw new Error(`Gemini call failed: ${res.status} ${await res.text()}`);
  }
  const data = (await res.json()) as Record<string, any>;
  if (data.candidates[0].finishReason === "MAX_TOKENS") {
    throw new Error("Gemini response truncated.");
  }
  const text = data.candidates[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error("Gemini response had no text.");
  }
  return { text, usage: { inputTokens: data.usageMetadata?.promptTokenCount, outputTokens: data.usageMetadata?.candidatesTokenCount } };
}
