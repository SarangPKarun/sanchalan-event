import { vi } from "vitest";

/** Standalone so the vi.mock factory can import it without pulling in app code. */
export const api = { get: vi.fn(), post: vi.fn(), patch: vi.fn(), delete: vi.fn() };
