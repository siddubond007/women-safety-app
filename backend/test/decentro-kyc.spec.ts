import { ForbiddenException } from "@nestjs/common";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { DecentroKycService } from "../src/eligibility/decentro-kyc.service.js";
import type { AuthenticationService } from "../src/auth/auth.service.js";
import type { PrismaService } from "../src/database/prisma.service.js";

describe("Decentro KYC fail-closed contract", () => {
  const priorEnvironment = new Map<string, string | undefined>();
  const environmentKeys = [
    "NODE_ENV",
    "SAKHI_ENV",
    "HOST",
    "SAKHI_ENABLE_LOCAL_ELIGIBILITY_SIMULATOR",
    "DECENTRO_BASE_URL",
    "DECENTRO_CLIENT_ID",
    "DECENTRO_CLIENT_SECRET",
    "DECENTRO_KYC_MODULE_SECRET",
    "APP_VERIFICATION_CALLBACK_URL",
    "DECENTRO_WEBHOOK_SECRET",
    "SAKHI_DECENTRO_POLICY_APPROVED",
  ];

  const auth = {
    authenticateAuthorization: vi.fn(),
    getRegistrationPolicy: vi.fn(),
  };
  const prisma: Record<string, unknown> = {};
  let service: DecentroKycService;

  beforeEach(() => {
    priorEnvironment.clear();
    for (const key of environmentKeys) {
      priorEnvironment.set(key, process.env[key]);
    }
    for (const key of Object.keys(prisma)) delete prisma[key];
    auth.authenticateAuthorization.mockResolvedValue({
      accountId: "9fc30b31-8bce-4f0e-99ab-fbf9a65bd4b3",
    });
    auth.getRegistrationPolicy.mockResolvedValue({ minimumAgeYears: 18 });
    service = new DecentroKycService(
      auth as unknown as AuthenticationService,
      prisma as unknown as PrismaService,
    );
  });

  afterEach(() => {
    for (const key of environmentKeys) {
      const prior = priorEnvironment.get(key);
      if (prior === undefined) delete process.env[key];
      else process.env[key] = prior;
    }
    vi.unstubAllGlobals();
    vi.resetAllMocks();
  });

  it("keeps provider readiness off until credentials, callback URL, and policy gate are configured", () => {
    process.env.DECENTRO_CLIENT_ID = "";
    process.env.DECENTRO_CLIENT_SECRET = "";
    process.env.APP_VERIFICATION_CALLBACK_URL = "";
    process.env.SAKHI_DECENTRO_POLICY_APPROVED = "false";

    expect(service.configuration()).toMatchObject({
      providerConfigured: false,
      canStartVerification: false,
      localSimulatorEnabled: false,
    });
  });

  it("simulates eligible demographics without persisting account verification", async () => {
    process.env.NODE_ENV = "development";
    process.env.SAKHI_ENV = "dev";
    process.env.HOST = "127.0.0.1";
    process.env.SAKHI_ENABLE_LOCAL_ELIGIBILITY_SIMULATOR = "true";

    const result = await service.simulateLocalResult(
      "Bearer local-test-session",
      { gender: "F", dob: "1999-05-15" },
    );

    expect(result).toMatchObject({
      status: "SIMULATION_ONLY",
      eligibilityStatus: "SIMULATION_PASSED",
      persisted: false,
      identityVerified: false,
      verificationStatusChanged: false,
      isDemo: true,
    });
    expect(auth.authenticateAuthorization).toHaveBeenCalledTimes(1);
  });

  it("does not run the simulator outside loopback development", async () => {
    process.env.NODE_ENV = "production";
    process.env.SAKHI_ENV = "staging";
    process.env.HOST = "0.0.0.0";
    process.env.SAKHI_ENABLE_LOCAL_ELIGIBILITY_SIMULATOR = "true";

    await expect(
      service.simulateLocalResult("Bearer staging-session", {
        gender: "F",
        dob: "1999-05-15",
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(auth.authenticateAuthorization).not.toHaveBeenCalled();
  });

  it("uses provider-returned demographics server-side and does not persist raw identity data", async () => {
    process.env.DECENTRO_BASE_URL = "https://in.staging.decentro.tech";
    process.env.DECENTRO_CLIENT_ID = "synthetic-test-client-id";
    process.env.DECENTRO_CLIENT_SECRET = "synthetic-test-client-secret";
    process.env.DECENTRO_KYC_MODULE_SECRET = "";
    process.env.APP_VERIFICATION_CALLBACK_URL =
      "https://sakhi.example.test/api/v1/eligibility/decentro/callback";
    process.env.SAKHI_DECENTRO_POLICY_APPROVED = "true";

    const accountId = "9fc30b31-8bce-4f0e-99ab-fbf9a65bd4b3";
    const referenceId = "42d43dd8-7f49-41e5-9b1f-e7f26b9ec706";
    const initialTxnId = "DECENTRO_SYNTHETIC_TXN";
    const fakeAadhaarUid = "FAKE-NOT-A-REAL-AADHAAR-UID";
    const initiation = {
      actorId: accountId,
      createdAt: new Date(Date.now() - 5_000),
      redactedMetadata: {
        decentroTxnId: initialTxnId,
        consentVersion: "sakhi-decentro-kyc-v1",
      },
    };

    const rootAuditFindFirst = vi.fn(async (args: unknown) => {
      const query = args as { where?: { action?: string } };
      return query.where?.action === "eligibility.decentro.session_initiated"
        ? initiation
        : null;
    });
    const txAuditEvent = {
      findFirst: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockResolvedValue({ id: "audit-entry" }),
    };
    const txMemberAccount = {
      update: vi.fn().mockResolvedValue({
        id: accountId,
        status: "ACTIVE",
        verificationStatus: "VERIFIED",
        updatedAt: new Date(),
      }),
    };
    const txEligibilitySubmission = {
      findFirst: vi.fn().mockResolvedValue(null),
      create: vi.fn().mockResolvedValue({ id: "submission-entry" }),
    };
    const tx = {
      auditEvent: txAuditEvent,
      memberAccount: txMemberAccount,
      eligibilitySubmission: txEligibilitySubmission,
    };
    Object.assign(prisma, {
      auditEvent: {
        findFirst: rootAuditFindFirst,
        create: vi.fn().mockResolvedValue({ id: "root-audit-entry" }),
      },
      memberAccount: {
        findUnique: vi.fn().mockResolvedValue({
          id: accountId,
          status: "PENDING_VERIFICATION",
          verificationStatus: "UNVERIFIED",
        }),
      },
      $transaction: vi.fn(
        async (callback: (client: unknown) => Promise<unknown>) =>
          callback(tx),
      ),
    });

    const fetchMock = vi.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          status: "SUCCESS",
          responseCode: "S00000",
          responseKey: "success_eaadhaar_download",
          data: {
            aadhaarUid: fakeAadhaarUid,
            proofOfIdentity: {
              gender: "F",
              dob: "15-05-1999",
              name: "Synthetic Test Person",
            },
          },
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
    vi.stubGlobal("fetch", fetchMock);

    const result = await service.completeBrowserCallback(referenceId);

    expect(result).toMatchObject({
      status: "verified",
      eligibilityStatus: "APPROVED",
      accountStatus: "ACTIVE",
      verificationStatus: "VERIFIED",
      genderMatchedFemale: true,
      ageVerifiedAboveMinimum: true,
      isDemo: false,
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(String(fetchMock.mock.calls[0]?.[0])).toContain(
      "/v2/kyc/digilocker/eaadhaar",
    );
    const init = fetchMock.mock.calls[0]?.[1] as RequestInit;
    expect(JSON.parse(String(init.body))).toMatchObject({
      initial_decentro_transaction_id: initialTxnId,
      consent: true,
    });
    expect(txMemberAccount.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: accountId },
        data: { status: "ACTIVE", verificationStatus: "VERIFIED" },
      }),
    );

    const persistedWrites = JSON.stringify([
      txAuditEvent.create.mock.calls,
      txEligibilitySubmission.create.mock.calls,
    ]);
    expect(persistedWrites).not.toContain(fakeAadhaarUid);
    expect(persistedWrites).not.toContain("15-05-1999");
    expect(persistedWrites).not.toContain("Synthetic Test Person");
  });
});
