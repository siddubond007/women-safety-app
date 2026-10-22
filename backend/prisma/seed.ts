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

    const accountIdByUsername = new Map<string, string>();
    for (const member of SEEDED_COMMUNITY_MEMBERS) {
      const acc = await prisma.memberAccount.upsert({
        where: { phoneE164: member.phoneE164 },
        update: {
          status: member.status,
          verificationStatus: member.verificationStatus,
        },
        create: {
          phoneE164: member.phoneE164,
          phoneVerifiedAt: new Date("2026-10-17T08:00:00.000Z"),
          status: member.status,
          verificationStatus: member.verificationStatus,
        },
        select: { id: true },
      });
      accountIdByUsername.set(member.username, acc.id);

      await prisma.memberProfile.upsert({
        where: { accountId: acc.id },
        update: {
          displayName: member.displayName,
          username: member.username,
          bio: member.bio,
          location: member.location,
          avatarAsset: member.avatarAsset,
          interests: member.interests,
          email: member.email,
        },
        create: {
          accountId: acc.id,
          displayName: member.displayName,
          username: member.username,
          bio: member.bio,
          location: member.location,
          avatarAsset: member.avatarAsset,
          interests: member.interests,
          dateOfBirth: new Date("1999-05-15T00:00:00.000Z"),
          email: member.email,
        },
      });

      if (member.username !== "@siddhu") {
        await prisma.communityDirectoryProfile.upsert({
          where: { username: member.username },
          update: {
            name: member.displayName,
            avatarAsset: member.avatarAsset,
            bio: member.bio,
            defaultFollowing: member.defaultFollowing,
          },
          create: {
            name: member.displayName,
            username: member.username,
            avatarAsset: member.avatarAsset,
            bio: member.bio,
            defaultFollowing: member.defaultFollowing,
          },
        });
      }

      if (member.verificationStatus === "UNVERIFIED") {
        const existingSub = await prisma.eligibilitySubmission.findFirst({
          where: { accountId: acc.id, status: "PENDING_MANUAL_REVIEW" },
          select: { id: true },
        });
        if (!existingSub) {
          await prisma.eligibilitySubmission.create({
            data: {
              accountId: acc.id,
              status: "PENDING_MANUAL_REVIEW",
              consentVersion: "dev-manual-review-v1",
              consentAcceptedAt: new Date(),
            },
          });
        }
      }
    }

    process.stdout.write(
      "Synthetic seed completed for " +
        target.databaseName +
        ". 8 community accounts, Module 2 fixtures, and draft policy metadata are present.\n",
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
