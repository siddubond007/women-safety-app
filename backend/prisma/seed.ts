import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../src/generated/prisma/client.js";
import {
  assertSakhiDatabaseTarget,
  parseSakhiEnvironment,
} from "../src/config/database-target.js";

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

    // Consent is deliberately not seeded: a fixture must never imply that a user accepted a policy.
    process.stdout.write(
      "Synthetic seed completed for " +
        target.databaseName +
        ". One reserved demo account and draft-only policy metadata are present.\n",
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
