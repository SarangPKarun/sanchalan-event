import { afterAll, beforeAll, describe, expect, it } from "vitest";

const url = process.env["TEST_DATABASE_URL"];
const safe = !!url && !/neon\.tech/i.test(url);
const suite = safe ? describe : describe.skip;

const run = Math.random().toString(36).slice(2, 8);
const key = (s: string) => `t${run}_${s}`;

suite("database-backed admin services", () => {
  let prisma: typeof import("../lib/prisma.js").prisma;
  let proposals: typeof import("../services/category-proposal.service.js");
  let team: typeof import("../services/admin-team.service.js");
  let auth: typeof import("../services/admin-auth.service.js");
  let catalog: typeof import("../services/admin-catalog.service.js");
  let oversight: typeof import("../services/admin-oversight.service.js");
  let superId: string;
  const vendorIds: string[] = [];
  const organizerIds: string[] = [];

  beforeAll(async () => {
    ({ prisma } = await import("../lib/prisma.js"));
    proposals = await import("../services/category-proposal.service.js");
    team = await import("../services/admin-team.service.js");
    auth = await import("../services/admin-auth.service.js");
    catalog = await import("../services/admin-catalog.service.js");
    oversight = await import("../services/admin-oversight.service.js");
    const { hashPassword } = await import("../lib/hash.js");
    const admin = await prisma.admin.create({
      data: { name: "T", email: `${run}-super@test.dev`, passwordHash: await hashPassword("correct-horse-battery"), role: "super_admin" },
    });
    superId = admin.id;
  });

  afterAll(async () => {
    if (!prisma) return;
    await prisma.adminAuditLog.deleteMany({ where: { OR: [{ adminId: superId }, { entityId: { contains: run } }] } });
    await prisma.refreshToken.deleteMany({ where: { userId: superId } });
    await prisma.taskTemplate.deleteMany({ where: { taskKey: { startsWith: `t${run}` } } });
    await prisma.categoryProposalVendor.deleteMany({ where: { vendorId: { in: vendorIds } } });
    await prisma.categoryProposal.deleteMany({ where: { categoryKey: { startsWith: `t${run}` } } });
    await prisma.vendorVendorCategory.deleteMany({ where: { vendorId: { in: vendorIds } } });
    await prisma.vendorCategory.deleteMany({ where: { categoryKey: { startsWith: `t${run}` } } });
    await prisma.taskCategory.deleteMany({ where: { categoryKey: { startsWith: `t${run}` } } });
    await prisma.vendor.deleteMany({ where: { id: { in: vendorIds } } });
    await prisma.refreshToken.deleteMany({ where: { userId: { in: organizerIds } } });
    await prisma.organizer.deleteMany({ where: { id: { in: organizerIds } } });
    await prisma.admin.deleteMany({ where: { email: { contains: run } } });
    await prisma.$disconnect();
  });

  it("dedupes proposals, approves once, and assigns the requesting vendors", async () => {
    const a = await prisma.vendor.create({ data: { phoneNumber: `+91${run}01`, status: "draft" } });
    const b = await prisma.vendor.create({ data: { phoneNumber: `+91${run}02`, status: "draft" } });
    vendorIds.push(a.id, b.id);

    const label = `T${run} Mehendi`;
    const p1 = await proposals.proposeCategory(a.id, { label });
    const p2 = await proposals.proposeCategory(b.id, { label: label.toLowerCase() });
    expect(p2.id).toBe(p1.id);

    const approve = (l: string) =>
      proposals.approveProposal(p1.id, superId, {
        label: l,
        applicableEventTypes: ["wedding"],
        templates: [{ taskKey: key("book"), defaultNameEn: "Book", defaultLeadTimeDays: 30, defaultDependencyKeys: [], typicalOwnerType: "organizer" }],
      });
    const done = await approve("Mehendi");
    expect(done.status).toBe("approved");
    expect(await prisma.vendorVendorCategory.count({ where: { vendorId: { in: [a.id, b.id] } } })).toBe(2);
    await expect(approve("Mehendi again")).rejects.toMatchObject({ status: 409 });
  });

  it("refuses to disable yourself or the last super admin", async () => {
    await expect(team.updateAdmin(superId, superId, { status: "disabled" })).rejects.toMatchObject({ status: 409 });
    const other = await prisma.admin.create({
      data: { name: "R", email: `${run}-rev@test.dev`, passwordHash: "x", role: "vendor_reviewer" },
    });
    // Make ours the only active super admin for the duration of the check.
    const others = await prisma.admin.findMany({ where: { role: "super_admin", status: "active", id: { not: superId } }, select: { id: true } });
    await prisma.admin.updateMany({ where: { id: { in: others.map((o) => o.id) } }, data: { status: "disabled" } });
    try {
      await expect(team.updateAdmin(other.id, superId, { role: "support" })).rejects.toMatchObject({ status: 409 });
      await expect(team.updateAdmin(other.id, superId, { status: "disabled" })).rejects.toMatchObject({ status: 409 });
    } finally {
      await prisma.admin.updateMany({ where: { id: { in: others.map((o) => o.id) } }, data: { status: "active" } });
    }
  });

  it("locks an account after repeated failed logins", async () => {
    const email = `${run}-super@test.dev`;
    for (let i = 0; i < auth.MAX_FAILED_LOGINS; i++)
      await expect(auth.adminLogin(email, "wrong", `10.0.0.${i}`)).rejects.toMatchObject({ status: 401 });
    await expect(auth.adminLogin(email, "correct-horse-battery", "10.0.1.1")).rejects.toMatchObject({ status: 429 });
  });

  it("validates template dependencies and blocks deleting a depended-on task", async () => {
    await prisma.taskCategory.create({ data: { categoryKey: key("cat"), applicableEventTypes: ["wedding"] } });
    const base = { categoryKey: key("cat"), eventType: "wedding" as const, defaultLeadTimeDays: 10, typicalOwnerType: "organizer" as const };
    const a = await catalog.createTemplate(superId, { ...base, taskKey: key("a"), defaultNameEn: "A", defaultDependencyKeys: [] });
    await expect(catalog.createTemplate(superId, { ...base, taskKey: key("x"), defaultNameEn: "X", defaultDependencyKeys: ["missing_key"] })).rejects.toMatchObject({ status: 400 });
    const b = await catalog.createTemplate(superId, { ...base, taskKey: key("b"), defaultNameEn: "B", defaultDependencyKeys: [key("a")] });
    await expect(catalog.updateTemplate(superId, a.id, { defaultDependencyKeys: [key("b")] })).rejects.toMatchObject({ status: 400 });
    await expect(catalog.deleteTemplate(superId, a.id)).rejects.toMatchObject({ status: 409 });
    await catalog.deleteTemplate(superId, b.id);
    await catalog.deleteTemplate(superId, a.id);
  });

  it("suspends and restores an organizer once, revoking their sessions", async () => {
    const o = await prisma.organizer.create({ data: { phoneNumber: `+91${run}77`, status: "active" } });
    organizerIds.push(o.id);
    await prisma.refreshToken.create({
      data: { id: crypto.randomUUID(), tokenHash: "x", userId: o.id, role: "organizer", expiresAt: new Date(Date.now() + 1e9) },
    });

    await expect(oversight.setOrganizerStatus(superId, o.id, "active")).rejects.toMatchObject({ status: 409 });
    const suspended = await oversight.setOrganizerStatus(superId, o.id, "suspended", "Abuse");
    expect(suspended.status).toBe("suspended");
    expect(await prisma.refreshToken.count({ where: { userId: o.id, revokedAt: null } })).toBe(0);
    await expect(oversight.setOrganizerStatus(superId, o.id, "suspended", "again")).rejects.toMatchObject({ status: 409 });

    const detail = await oversight.getOrganizer(o.id);
    expect(detail.suspension?.metadata).toEqual({ reason: "Abuse" });
    expect((await oversight.setOrganizerStatus(superId, o.id, "active")).status).toBe("active");
  });

  it("neutralises spreadsheet formulas in the audit CSV export", async () => {
    await prisma.adminAuditLog.create({
      data: { adminId: superId, action: "=HYPERLINK(\"http://evil\")", entityType: "vendor", entityId: `${run}-csv` },
    });
    const csv = await oversight.auditCsv({ entityType: "vendor", page: 1, pageSize: 20 });
    const line = csv.split("\n").find((l) => l.includes(`${run}-csv`))!;
    expect(line).toContain(`"'=HYPERLINK(`);
    expect(line).not.toContain(`,"=HYPERLINK`);
  });
});
