import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
  ServiceUnavailableException,
} from "@nestjs/common";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { Module2Service } from "../src/module2/module2.service.js";
import type { AuthenticationService } from "../src/auth/auth.service.js";
import type { PrismaService } from "../src/database/prisma.service.js";

const accountId = "b735d34b-6da0-4a01-b1be-1aeb7564f731";
const currentSessionId = "f8d31bca-b3d7-4953-8ff1-9c0b1354d3bc";
const otherSessionId = "5a23b326-329c-4f20-9c5b-b2d1268855e8";

describe("Module 2 account session management", () => {
  const authenticateAuthorization = vi.fn();
  const authSession = {
    findMany: vi.fn(),
    findFirst: vi.fn(),
    updateMany: vi.fn(),
  };
  const auditEvent = { create: vi.fn() };
  const memberProfile = { update: vi.fn() };
  let service: Module2Service;

  beforeEach(() => {
    vi.clearAllMocks();
    authenticateAuthorization.mockResolvedValue({
      id: currentSessionId,
      accountId,
      account: { status: "ACTIVE", verificationStatus: "VERIFIED" },
    });
    service = new Module2Service(
      { authenticateAuthorization } as unknown as AuthenticationService,
      {
        authSession,
        auditEvent,
        memberProfile,
      } as unknown as PrismaService,
    );
  });

  it("lists only safe session metadata for the authenticated account", async () => {
    const createdAt = new Date("2026-10-30T10:00:00.000Z");
    const expiresAt = new Date("2026-11-30T10:00:00.000Z");
    authSession.findMany.mockResolvedValue([
      {
        id: currentSessionId,
        createdAt,
        expiresAt,
        revokedAt: null,
        lastSeenAt: null,
        deviceName: "Android app",
        tokenDigest: "must-never-be-selected",
      },
      {
        id: otherSessionId,
        createdAt: new Date("2026-10-29T10:00:00.000Z"),
        expiresAt,
        revokedAt: null,
        lastSeenAt: null,
        deviceName: "Windows app",
      },
    ]);

    const result = await service.listLoginSessions("Bearer synthetic-token");

    expect(authSession.findMany).toHaveBeenCalledWith({
      where: { accountId },
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        createdAt: true,
        expiresAt: true,
        revokedAt: true,
        lastSeenAt: true,
        deviceName: true,
      },
    });
    expect(result.sessions).toHaveLength(2);
    expect(result.sessions[0]).toMatchObject({
      id: currentSessionId,
      createdAt,
      expiresAt,
      deviceName: "Android app",
      isCurrent: true,
      isActive: true,
    });
    expect(result.sessions[1]).toMatchObject({
      id: otherSessionId,
      deviceName: "Windows app",
      isCurrent: false,
      isActive: true,
    });
    expect(JSON.stringify(result)).not.toContain("tokenDigest");
  });

  it("revokes an active session only after confirming account ownership", async () => {
    authSession.findFirst.mockResolvedValue({
      id: otherSessionId,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });
    authSession.updateMany.mockResolvedValue({ count: 1 });
    auditEvent.create.mockResolvedValue({});

    const result = await service.revokeLoginSession(
      "Bearer synthetic-token",
      otherSessionId,
    );

    expect(authSession.findFirst).toHaveBeenCalledWith({
      where: { id: otherSessionId, accountId },
      select: { id: true, revokedAt: true, expiresAt: true },
    });
    expect(authSession.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: otherSessionId,
          accountId,
          revokedAt: null,
        }),
        data: { revokedAt: expect.any(Date) },
      }),
    );
    expect(result).toEqual({ revoked: true, currentSession: false });
    expect(auditEvent.create).toHaveBeenCalledOnce();
  });

  it("prevents revoking the session used to authorize the request", async () => {
    authSession.findFirst.mockResolvedValue({
      id: currentSessionId,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });

    await expect(
      service.revokeLoginSession("Bearer synthetic-token", currentSessionId),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(authSession.updateMany).not.toHaveBeenCalled();
    expect(auditEvent.create).not.toHaveBeenCalled();
  });

  it("does not reveal or revoke another account's session", async () => {
    authSession.findFirst.mockResolvedValue(null);

    await expect(
      service.revokeLoginSession("Bearer synthetic-token", otherSessionId),
    ).rejects.toBeInstanceOf(NotFoundException);

    expect(authSession.updateMany).not.toHaveBeenCalled();
    expect(auditEvent.create).not.toHaveBeenCalled();
  });

  it("rejects malformed session identifiers before querying the database", async () => {
    await expect(
      service.revokeLoginSession("Bearer synthetic-token", "not-a-session-id"),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(authSession.findFirst).not.toHaveBeenCalled();
    expect(authSession.updateMany).not.toHaveBeenCalled();
  });

  it("does not claim to enable two-factor authentication without a provider", async () => {
    await expect(
      service.toggleTwoFactor("Bearer synthetic-token", { enabled: true }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);

    expect(memberProfile.update).not.toHaveBeenCalled();
  });

  it("does not claim to update a PIN when no verifiable PIN credential exists", async () => {
    await expect(
      service.updateSecurityPin("Bearer synthetic-token", { newPin: "1234" }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);

    expect(memberProfile.update).not.toHaveBeenCalled();
  });
});
