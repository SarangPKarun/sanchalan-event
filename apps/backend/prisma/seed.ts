import { PrismaClient, type TaskOwnerType } from "@prisma/client";
import { randomBytes } from "node:crypto";
import bcrypt from "bcryptjs";

const prisma = new PrismaClient();

const SEED_ADMIN_EMAIL = "admin@sanchalan.internal";
const BCRYPT_ROUNDS = 10;

const CATEGORY_KEYS = [
  "venue",
  "catering",
  "decor",
  "photography",
  "attire",
  "invitations",
  "music_entertainment",
  "legal_documentation",
  "guest_logistics",
  "priest_officiant",
  "transport",
  "misc",
] as const;

type CategoryKey = (typeof CATEGORY_KEYS)[number];

// Vendor categories describe a vendor *business type* a family would search
// for — a subset of CATEGORY_KEYS, dropping ones that only make sense as
// planning-task categories (legal_documentation, guest_logistics).
const VENDOR_CATEGORY_KEYS = [
  "venue",
  "catering",
  "decor",
  "photography",
  "attire",
  "invitations",
  "music_entertainment",
  "priest_officiant",
  "transport",
  "misc",
] as const;

interface TemplateSeed {
  taskKey: string;
  categoryKey: CategoryKey;
  defaultNameEn: string;
  defaultLeadTimeDays: number;
  defaultDependencyKeys: string[];
}

const TEMPLATES: TemplateSeed[] = [
  {
    taskKey: "book_venue",
    categoryKey: "venue",
    defaultNameEn: "Book venue",
    defaultLeadTimeDays: 120,
    defaultDependencyKeys: [],
  },
  {
    taskKey: "finalize_guest_count",
    categoryKey: "guest_logistics",
    defaultNameEn: "Finalize guest count",
    defaultLeadTimeDays: 100,
    defaultDependencyKeys: [],
  },
  {
    taskKey: "book_catering",
    categoryKey: "catering",
    defaultNameEn: "Book catering",
    defaultLeadTimeDays: 90,
    defaultDependencyKeys: ["finalize_guest_count"],
  },
  {
    taskKey: "finalize_catering_menu",
    categoryKey: "catering",
    defaultNameEn: "Finalize catering menu",
    defaultLeadTimeDays: 45,
    defaultDependencyKeys: ["book_catering"],
  },
  {
    taskKey: "book_photographer",
    categoryKey: "photography",
    defaultNameEn: "Book photographer",
    defaultLeadTimeDays: 90,
    defaultDependencyKeys: [],
  },
  {
    taskKey: "book_decor_vendor",
    categoryKey: "decor",
    defaultNameEn: "Book decor vendor",
    defaultLeadTimeDays: 60,
    defaultDependencyKeys: ["book_venue"],
  },
  {
    taskKey: "send_invitations",
    categoryKey: "invitations",
    defaultNameEn: "Send invitations",
    defaultLeadTimeDays: 60,
    defaultDependencyKeys: ["finalize_guest_count"],
  },
  {
    taskKey: "book_priest_officiant",
    categoryKey: "priest_officiant",
    defaultNameEn: "Book priest/officiant",
    defaultLeadTimeDays: 45,
    defaultDependencyKeys: [],
  },
  {
    taskKey: "arrange_transport",
    categoryKey: "transport",
    defaultNameEn: "Arrange transport",
    defaultLeadTimeDays: 30,
    defaultDependencyKeys: [],
  },
  {
    taskKey: "finalize_attire",
    categoryKey: "attire",
    defaultNameEn: "Finalize attire",
    defaultLeadTimeDays: 45,
    defaultDependencyKeys: [],
  },
  {
    taskKey: "book_music_entertainment",
    categoryKey: "music_entertainment",
    defaultNameEn: "Book music & entertainment",
    defaultLeadTimeDays: 60,
    defaultDependencyKeys: [],
  },
  {
    taskKey: "marriage_registration_documents",
    categoryKey: "legal_documentation",
    defaultNameEn: "Prepare marriage registration documents",
    defaultLeadTimeDays: 30,
    defaultDependencyKeys: [],
  },
  {
    taskKey: "confirm_final_headcount",
    categoryKey: "guest_logistics",
    defaultNameEn: "Confirm final headcount",
    defaultLeadTimeDays: 7,
    defaultDependencyKeys: ["send_invitations"],
  },
  {
    taskKey: "vendor_final_payments",
    categoryKey: "misc",
    defaultNameEn: "Complete vendor final payments",
    defaultLeadTimeDays: 7,
    defaultDependencyKeys: [],
  },
];

const TYPICAL_OWNER_TYPE: TaskOwnerType = "organizer";

function assertNoOrphanedDependencyKeys(): void {
  const knownTaskKeys = new Set(TEMPLATES.map((t) => t.taskKey));
  for (const template of TEMPLATES) {
    for (const dep of template.defaultDependencyKeys) {
      if (!knownTaskKeys.has(dep)) {
        throw new Error(
          `Orphaned dependency key "${dep}" on template "${template.taskKey}" — no template with that taskKey exists.`
        );
      }
    }
  }
}

async function main() {
  assertNoOrphanedDependencyKeys();

  const categoryIdByKey = new Map<CategoryKey, string>();
  for (const categoryKey of CATEGORY_KEYS) {
    const category = await prisma.taskCategory.upsert({
      where: { categoryKey },
      update: { applicableEventTypes: ["wedding"] },
      create: { categoryKey, applicableEventTypes: ["wedding"] },
    });
    categoryIdByKey.set(categoryKey, category.id);
  }

  // TaskTemplate.taskKey has no unique constraint, so re-running this seed
  // would otherwise duplicate every row — clear our own rows first instead.
  await prisma.taskTemplate.deleteMany({
    where: { eventType: "wedding", taskKey: { in: TEMPLATES.map((t) => t.taskKey) } },
  });

  for (const template of TEMPLATES) {
    await prisma.taskTemplate.create({
      data: {
        eventType: "wedding",
        region: null,
        religionOrTradition: null,
        taskCategoryId: categoryIdByKey.get(template.categoryKey)!,
        taskKey: template.taskKey,
        defaultNameEn: template.defaultNameEn,
        defaultLeadTimeDays: template.defaultLeadTimeDays,
        defaultDependencyKeys: template.defaultDependencyKeys,
        typicalOwnerType: TYPICAL_OWNER_TYPE,
        version: 1,
      },
    });
  }

  console.log(
    `Seeded ${CATEGORY_KEYS.length} task categories and ${TEMPLATES.length} task templates.`
  );

  await seedVendorCategories();
  await seedAdmin();
  // Opt-in only: never creates fake vendors on a real database by default.
  if (process.env.SEED_SAMPLE_VENDORS === "true") await seedSampleVendors();
}

const SAMPLE_VENDORS = [
  { phone: "+919990000001", name: "Rang Mandap Decor", category: "decor", status: "published" },
  { phone: "+919990000002", name: "Shubh Lens Photography", category: "photography", status: "pending_review" },
  { phone: "+919990000003", name: "Annapurna Caterers", category: "catering", status: "rejected" },
  { phone: "+919990000004", name: "Draft Venue Co", category: "venue", status: "draft" },
] as const;

async function seedSampleVendors(): Promise<void> {
  for (const sample of SAMPLE_VENDORS) {
    const existing = await prisma.vendor.findUnique({ where: { phoneNumber: sample.phone } });
    if (existing) continue;

    const category = await prisma.vendorCategory.findUniqueOrThrow({
      where: { categoryKey: sample.category },
    });
    const isDraft = sample.status === "draft";
    await prisma.vendor.create({
      data: {
        phoneNumber: sample.phone,
        status: sample.status,
        businessName: sample.name,
        contactPersonName: "Sample Owner",
        priceTier: "standard",
        serviceArea: "Pune",
        description: `${sample.name} has been serving weddings and family events across Pune for over a decade.`,
        yearsOfExperience: 10,
        startingPrice: 50000,
        submittedAt: isDraft ? null : new Date(),
        rejectionReason: sample.status === "rejected" ? "Please add more details about past events." : null,
        ...(isDraft
          ? {}
          : {
              vendorVendorCategories: { create: { vendorCategoryId: category.id } },
              portfolioItems: {
                create: { title: "Sharma wedding, Pune", caption: "400 guests, 3-day event", displayOrder: 0 },
              },
            }),
      },
    });
  }
  console.log(`Seeded sample vendors (${SAMPLE_VENDORS.length}).`);
}

async function seedVendorCategories(): Promise<void> {
  for (const categoryKey of VENDOR_CATEGORY_KEYS) {
    await prisma.vendorCategory.upsert({
      where: { categoryKey },
      update: { applicableEventTypes: ["wedding"] },
      create: { categoryKey, applicableEventTypes: ["wedding"] },
    });
  }
  console.log(`Seeded ${VENDOR_CATEGORY_KEYS.length} vendor categories.`);
}

async function seedAdmin(): Promise<void> {
  const existing = await prisma.admin.findUnique({ where: { email: SEED_ADMIN_EMAIL } });
  if (existing) {
    console.log(`Admin already seeded (${SEED_ADMIN_EMAIL}).`);
    return;
  }

  const password = randomBytes(18).toString("base64url");
  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

  await prisma.admin.create({
    data: {
      name: "Seed Admin",
      email: SEED_ADMIN_EMAIL,
      passwordHash,
      role: "super_admin",
      mustChangePassword: true,
    },
  });

  console.log("=".repeat(72));
  console.log(`Seeded admin account — save this password now, it will not be shown again:`);
  console.log(`  email:    ${SEED_ADMIN_EMAIL}`);
  console.log(`  password: ${password}`);
  console.log("=".repeat(72));
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
