import "reflect-metadata";
import type { INestApplication } from "@nestjs/common";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Test } from "@nestjs/testing";
import request from "supertest";
import { createGlobalValidationPipe } from "../src/common/validation/create-validation-pipe.js";
import { AuthenticationService } from "../src/auth/auth.service.js";
import { PrismaService } from "../src/database/prisma.service.js";
import { ProfileController } from "../src/profile/profile.controller.js";
import { UpdateMyProfileDto } from "../src/profile/profile.dto.js";
import { ProfileService } from "../src/profile/profile.service.js";

const OWNER_ID = "b4dbffb8-c3ab-4d90-b3a9-92d79e5e2a11";
const OTHER_ID = "b7aab3dd-66b7-4d6b-8d7b-d3e98495db2e";
const INITIAL_PROFILE = {
  accountId: OWNER_ID,
  displayName: "Asha Rao",
  dateOfBirth: new Date("1995-05-05T00:00:00.000Z"),
  email: "asha@example.com",
  bio: null as string | null,
  city: null as string | null,
  updatedAt: new Date("2026-10-16T06:30:00.000Z"),
};

type FakeTx = {
  memberProfile: {
    findUnique: ReturnType<typeof vi.fn>;
    update: ReturnType<typeof vi.fn>;
  };
  auditEvent: { create: ReturnType<typeof vi.fn> };
};

function createHarness(
  initialProfile: typeof INITIAL_PROFILE | null = INITIAL_PROFILE,
) {
  let profile: typeof INITIAL_PROFILE | null = initialProfile;
  const tx: FakeTx = {
    memberProfile: {
      findUnique: vi.fn(async (args: { where: { accountId: string } }) =>
        args.where.accountId === OWNER_ID && profile
          ? { accountId: profile.accountId }
          : null,
      ),
      update: vi.fn(
        async (args: {
          where: { accountId: string };
          data: Record<string, unknown>;
        }) => {
          if (args.where.accountId !== OWNER_ID || profile === null) {
            throw new Error("Unexpected profile ownership");
          }
          profile = {
            ...profile,
            ...args.data,
            updatedAt: new Date("2026-10-16T06:35:00.000Z"),
          } as typeof INITIAL_PROFILE;
          return {
            displayName: profile.displayName,
            email: profile.email,
            bio: profile.bio,
            city: profile.city,
            updatedAt: profile.updatedAt,
          };
        },
      ),
    },
    auditEvent: {
      create: vi.fn().mockResolvedValue({ id: "audit-id" }),
    },
  };
  const prisma = {
    memberProfile: {
      findUnique: vi.fn(async (args: { where: { accountId: string } }) => {
        if (args.where.accountId !== OWNER_ID || profile === null) return null;
        return {
          displayName: profile.displayName,
          email: profile.email,
          bio: profile.bio,
          city: profile.city,
          updatedAt: profile.updatedAt,
        };
      }),
    },
    $transaction: vi.fn(
      async (callback: (tx: unknown) => Promise<unknown>) => callback(tx),
    ),
  } as unknown as PrismaService;

  const authentication = {
    authenticateAuthorization: vi.fn().mockResolvedValue({ accountId: OWNER_ID }),
  } as unknown as AuthenticationService;
  const service = new ProfileService(authentication, prisma);

  return { service, authentication, prisma, tx, getProfile: () => profile };
}

describe("member profile API", () => {
  let app: INestApplication | undefined;

  afterEach(async () => {
    if (app) {
      await app.close();
      app = undefined;
    }
    vi.restoreAllMocks();
  });

  async function createApp(harness = createHarness()) {
    // Vitest's esbuild transform does not emit the controller's constructor
    // and DTO reflection metadata, so provide the metadata emitted by tsc.
    Reflect.defineMetadata(
      "design:paramtypes",
      [ProfileService],
      ProfileController,
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [String],
      ProfileController.prototype,
      "getMe",
    );
    Reflect.defineMetadata(
      "design:paramtypes",
      [String, UpdateMyProfileDto],
      ProfileController.prototype,
      "updateMe",
    );
    const module = await Test.createTestingModule({
      controllers: [ProfileController],
      providers: [{ provide: ProfileService, useValue: harness.service }],
    }).compile();
    const testApp = module.createNestApplication();
    testApp.setGlobalPrefix("api/v1");
    testApp.useGlobalPipes(createGlobalValidationPipe());
    await testApp.init();
    app = testApp;
    return { testApp, harness };
  }

  it("reads only the authenticated member's own profile", async () => {
    const { testApp, harness } = await createApp();
    const response = await request(testApp.getHttpServer())
      .get("/api/v1/profile/me")
      .set("authorization", "Bearer test-development-token")
      .expect(200);

    expect(harness.authentication.authenticateAuthorization).toHaveBeenCalledWith(
      "Bearer test-development-token",
    );
    expect(harness.prisma.memberProfile.findUnique).toHaveBeenCalledWith({
      where: { accountId: OWNER_ID },
      select: {
        displayName: true,
        email: true,
        bio: true,
        city: true,
        updatedAt: true,
      },
    });
    expect(response.body.profile.displayName).toBe("Asha Rao");
    expect(response.body.profile).not.toHaveProperty("dateOfBirth");
    expect(response.body.profile).not.toHaveProperty("accountId");
  });

  it("updates allowed fields and audits only their names", async () => {
    const { testApp, harness } = await createApp();
    const response = await request(testApp.getHttpServer())
      .patch("/api/v1/profile/me")
      .set("authorization", "Bearer test-development-token")
      .send({
        displayName: " Asha Rao ",
        email: "ASHA@EXAMPLE.COM",
        bio: "Community volunteer",
        city: "Hyderabad",
      })
      .expect(200);

    expect(harness.tx.memberProfile.update).toHaveBeenCalledWith({
      where: { accountId: OWNER_ID },
      data: {
        displayName: "Asha Rao",
        email: "asha@example.com",
        bio: "Community volunteer",
        city: "Hyderabad",
      },
      select: {
        displayName: true,
        email: true,
        bio: true,
        city: true,
        updatedAt: true,
      },
    });
    expect(response.body.profile).toMatchObject({
      displayName: "Asha Rao",
      email: "asha@example.com",
      bio: "Community volunteer",
      city: "Hyderabad",
    });
    expect(harness.tx.auditEvent.create).toHaveBeenCalledWith({
      data: {
        actorType: "MEMBER",
        actorId: OWNER_ID,
        action: "member.profile.updated",
        targetType: "member_profile",
        targetId: OWNER_ID,
        outcome: "success",
        requestId: expect.any(String),
        redactedMetadata: {
          changedFields: ["bio", "city", "displayName", "email"],
        },
      },
      select: { id: true },
    });
    expect(JSON.stringify(harness.tx.auditEvent.create.mock.calls)).not.toContain(
      "Community volunteer",
    );
  });

  it("rejects caller-supplied ownership IDs before mutation", async () => {
    const { testApp, harness } = await createApp();
    await request(testApp.getHttpServer())
      .patch("/api/v1/profile/me")
      .set("authorization", "Bearer test-development-token")
      .send({
        accountId: OTHER_ID,
        displayName: "Someone else",
      })
      .expect(400);

    expect(harness.tx.memberProfile.update).not.toHaveBeenCalled();
  });

  it("leaves optional fields unchanged when they are omitted", async () => {
    const { testApp, harness } = await createApp();
    await request(testApp.getHttpServer())
      .patch("/api/v1/profile/me")
      .set("authorization", "Bearer test-development-token")
      .send({ displayName: "Asha R." })
      .expect(200);

    expect(harness.tx.memberProfile.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { accountId: OWNER_ID },
        data: { displayName: "Asha R." },
      }),
    );
    expect(harness.getProfile()).toMatchObject({
      displayName: "Asha R.",
      email: "asha@example.com",
      bio: null,
      city: null,
    });
  });

  it("normalizes cleared optional fields to null", async () => {
    const { testApp, harness } = await createApp();
    const response = await request(testApp.getHttpServer())
      .patch("/api/v1/profile/me")
      .set("authorization", "Bearer test-development-token")
      .send({ email: null, bio: "", city: "  " })
      .expect(200);

    expect(response.body.profile).toMatchObject({
      email: null,
      bio: null,
      city: null,
    });
  });

  it("returns not found when the authenticated member has no profile", async () => {
    const { testApp, harness } = await createApp(null);
    await request(testApp.getHttpServer())
      .get("/api/v1/profile/me")
      .set("authorization", "Bearer test-development-token")
      .expect(404);
    expect(harness.prisma.memberProfile.findUnique).toHaveBeenCalledTimes(1);
  });

  it("rejects empty updates and invalid field values", async () => {
    const { testApp, harness } = await createApp();
    await request(testApp.getHttpServer())
      .patch("/api/v1/profile/me")
      .set("authorization", "Bearer test-development-token")
      .send({})
      .expect(400);

    await request(testApp.getHttpServer())
      .patch("/api/v1/profile/me")
      .set("authorization", "Bearer test-development-token")
      .send({ displayName: " " })
      .expect(400);
    expect(harness.tx.memberProfile.update).not.toHaveBeenCalled();
  });
});
