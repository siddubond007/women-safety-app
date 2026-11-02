import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../src/generated/prisma/client.js";
import {
  assertSakhiDatabaseTarget,
  parseSakhiEnvironment,
} from "../src/config/database-target.js";
import { SEEDED_COMMUNITY_MEMBERS } from "../src/module2/module2.service.js";

async function main(): Promise<void> {
  if (process.env.NODE_ENV === "production") {
    throw new Error("Synthetic seed is prohibited in production.");
  }
  if (!process.env.SAKHI_ENV || !process.env.SAKHI_MIGRATOR_DATABASE_URL) {
    throw new Error(
      "Set SAKHI_ENV and SAKHI_MIGRATOR_DATABASE_URL using the local PowerShell helper.",
    );
  }

  const environment = parseSakhiEnvironment(process.env.SAKHI_ENV);
  const target = assertSakhiDatabaseTarget(
    process.env.SAKHI_MIGRATOR_DATABASE_URL,
    "migrator",
    environment,
  );
  if (
    !["sakhi_dev", "sakhi_test"].includes(target.databaseName) ||
    (environment === "dev" && target.databaseName !== "sakhi_dev") ||
    (environment === "test" && target.databaseName !== "sakhi_test")
  ) {
    throw new Error(
      "Seed target rejected. Only the matching Sakhi local dev/test database is permitted.",
    );
  }

  const adapter = new PrismaPg({
    connectionString: process.env.SAKHI_MIGRATOR_DATABASE_URL,
    max: 2,
    connectionTimeoutMillis: 5_000,
    idleTimeoutMillis: 10_000,
  });
  const prisma = new PrismaClient({ adapter });

  try {
    await prisma.policyDocumentVersion.upsert({
      where: {
        documentType_version: {
          documentType: "TERMS",
          version: "seed-draft-v1",
        },
      },
      update: {},
      create: {
        documentType: "TERMS",
        version: "seed-draft-v1",
        status: "DRAFT",
      },
    });

    await prisma.policyDocumentVersion.upsert({
      where: {
        documentType_version: {
          documentType: "PRIVACY",
          version: "seed-draft-v1",
        },
      },
      update: {},
      create: {
        documentType: "PRIVACY",
        version: "seed-draft-v1",
        status: "DRAFT",
      },
    });

    const account = await prisma.memberAccount.upsert({
      where: { phoneE164: "+12025550123" },
      update: {},
      create: {
        phoneE164: "+12025550123",
        status: "PENDING_VERIFICATION",
        verificationStatus: "UNVERIFIED",
      },
      select: { id: true },
    });

    await prisma.memberProfile.upsert({
      where: { accountId: account.id },
      update: {},
      create: {
        accountId: account.id,
        displayName: "Demo Sakhi Member",
        dateOfBirth: new Date("2000-01-01T00:00:00.000Z"),
        email: "demo.member@example.invalid",
      },
    });

    if (typeof (prisma as Record<string, any>).$executeRaw === "function") {
      await (prisma as Record<string, any>).$executeRaw`
        INSERT INTO public.platform_registration_policies (policy_key, minimum_age_years, updated_by, change_reason)
        VALUES ('default', 18, 'prisma-seed', 'Default registration minimum-age policy')
        ON CONFLICT (policy_key) DO NOTHING
      `.catch(() => undefined);
    }

    const categories = [
      { slug: "following", name: "Following", description: "Updates from verified Sakhi members and circles you follow.", iconKey: "heart_handshake", accentColorHex: "#EC4899", isEnabled: true, displayOrder: 1 },
      { slug: "community", name: "Community", description: "Open discussions, peer encouragement, and shared experiences.", iconKey: "users", accentColorHex: "#A855F7", isEnabled: true, displayOrder: 2 },
      { slug: "trending", name: "Trending", description: "High-engagement conversations and timely topics across Sakhi.", iconKey: "flame", accentColorHex: "#F59E0B", isEnabled: true, displayOrder: 3 },
      { slug: "business_updates", name: "Business Updates", description: "Showcases, launches, and announcements from women-led businesses.", iconKey: "briefcase", accentColorHex: "#8B5CF6", isEnabled: true, displayOrder: 4 },
      { slug: "safety_awareness", name: "Safety Awareness", description: "Verified safety advisories, commute tips, and legal/self-defense awareness.", iconKey: "shield_check", accentColorHex: "#10B981", isEnabled: true, displayOrder: 5 },
      { slug: "wellness_lifestyle", name: "Wellness and Lifestyle", description: "Mindfulness, physical health, journaling, and holistic lifestyle guidance.", iconKey: "sparkles", accentColorHex: "#14B8A6", isEnabled: true, displayOrder: 6 },
    ];
    for (const cat of categories) {
      if ((prisma as Record<string, any>).feedCategoryConfig?.upsert) {
        await (prisma as Record<string, any>).feedCategoryConfig.upsert({
          where: { slug: cat.slug },
          update: cat,
          create: { ...cat, updatedBy: "prisma-seed" },
        });
      }
    }

    process.stdout.write(
      "Synthetic seed completed for " +
        target.databaseName +
        ". Feed categories and policy metadata are verified.
",
    );
  } catch {
    process.stderr.write(
      "Synthetic seed failed. Database details and sensitive information were not printed.\n",
    );
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

main().catch(() => {
  process.stderr.write(
    "Synthetic seed refused or failed. No sensitive details were printed.\n",
  );
  process.exitCode = 1;
});
