import { describe, expect, it } from "vitest";
import { can, permissionsFor } from "../lib/admin-permissions.js";
import { RateLimiter } from "../lib/rate-limit.js";
import { normalizeCategoryKey } from "../services/category-proposal.service.js";

describe("admin permissions", () => {
  it("gives support read-only access", () => {
    expect(permissionsFor("support")).toEqual([]);
    expect(can("support", "vendor.review")).toBe(false);
  });
  it("lets reviewers decide vendors and categories but not manage the team", () => {
    expect(can("vendor_reviewer", "vendor.review")).toBe(true);
    expect(can("vendor_reviewer", "category.manage")).toBe(true);
    expect(can("vendor_reviewer", "team.manage")).toBe(false);
    expect(can("vendor_reviewer", "audit.read")).toBe(false);
  });
  it("gives super admins everything", () => {
    for (const a of ["vendor.review", "team.manage", "audit.read", "organizer.manage"] as const)
      expect(can("super_admin", a)).toBe(true);
  });
});

describe("normalizeCategoryKey", () => {
  it.each([
    ["Mehendi Artist", "mehendi_artist"],
    ["  mehendi  artist! ", "mehendi_artist"],
    ["Décor & Lighting", "decor_and_lighting"],
    ["DJ/Sound", "dj_sound"],
  ])("%s -> %s", (input, key) => expect(normalizeCategoryKey(input)).toBe(key));
});

describe("RateLimiter", () => {
  it("allows up to max hits per window, then reports the wait", () => {
    const rl = new RateLimiter(2, 60_000);
    expect(rl.take("a", 0)).toBe(0);
    expect(rl.take("a", 1000)).toBe(0);
    expect(rl.take("a", 2000)).toBe(58);
    expect(rl.take("b", 2000)).toBe(0);
  });
  it("frees up once the window passes", () => {
    const rl = new RateLimiter(1, 1000);
    rl.take("a", 0);
    expect(rl.take("a", 500)).toBeGreaterThan(0);
    expect(rl.take("a", 1500)).toBe(0);
  });
});
