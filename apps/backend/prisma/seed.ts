import { PrismaClient, type TaskOwnerType } from "@prisma/client";

const prisma = new PrismaClient();

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
    defaultLeadTimeDays: 90,
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
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
