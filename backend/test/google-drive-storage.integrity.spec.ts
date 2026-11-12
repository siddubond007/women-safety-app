import { createHash } from "node:crypto";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { GoogleDriveStorageService } from "../src/module2/google-drive-storage.service.js";

const driveFileId = "drive_file_1234567890";
const evidenceId = "0123456789abcdef0123456789abcdef";
const accountId = "2f6f7fa1-8c5c-4bb0-ae1a-0f7e3a2e5a41";
const bytes = Buffer.from("synthetic sakhi evidence object");
const sha256 = createHash("sha256").update(bytes).digest("hex");

function mockTokenAndMetadata(appProperties: Record<string, string>) {
  return [
    new Response(JSON.stringify({ access_token: "synthetic-access-token", expires_in: 3600 }), { status: 200 }),
    new Response(JSON.stringify({
      id: driveFileId,
      trashed: false,
      size: String(bytes.length),
      appProperties,
    }), { status: 200 }),
  ];
}

describe("Google Drive object integrity and ownership", () => {
  beforeEach(() => {
    process.env.SAKHI_GOOGLE_DRIVE_CLIENT_ID = "synthetic-client-id";
    process.env.SAKHI_GOOGLE_DRIVE_CLIENT_SECRET = "synthetic-client-secret";
    process.env.SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN = "synthetic-refresh-token";
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    delete process.env.SAKHI_GOOGLE_DRIVE_CLIENT_ID;
    delete process.env.SAKHI_GOOGLE_DRIVE_CLIENT_SECRET;
    delete process.env.SAKHI_GOOGLE_DRIVE_REFRESH_TOKEN;
  });

  it("retrieves and hashes complaint evidence bytes, not just Drive metadata", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(mockTokenAndMetadata({
        sakhiEvidenceId: evidenceId,
        sakhiClassification: "CONFIDENTIAL_COMPLAINT_EVIDENCE",
        sakhiSha256: sha256,
        sakhiByteSize: String(bytes.length),
      })[0])
      .mockResolvedValueOnce(mockTokenAndMetadata({
        sakhiEvidenceId: evidenceId,
        sakhiClassification: "CONFIDENTIAL_COMPLAINT_EVIDENCE",
        sakhiSha256: sha256,
        sakhiByteSize: String(bytes.length),
      })[1])
      .mockResolvedValueOnce(new Response(bytes, { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    const service = new GoogleDriveStorageService();

    await expect(service.verifyComplaintEvidenceFile(driveFileId, evidenceId, sha256, bytes.length)).resolves.toBe(true);
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it("rejects complaint evidence whose downloaded bytes do not match its SHA-256 receipt", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(mockTokenAndMetadata({
        sakhiEvidenceId: evidenceId,
        sakhiClassification: "CONFIDENTIAL_COMPLAINT_EVIDENCE",
        sakhiSha256: sha256,
        sakhiByteSize: String(bytes.length),
      })[0])
      .mockResolvedValueOnce(mockTokenAndMetadata({
        sakhiEvidenceId: evidenceId,
        sakhiClassification: "CONFIDENTIAL_COMPLAINT_EVIDENCE",
        sakhiSha256: sha256,
        sakhiByteSize: String(bytes.length),
      })[1])
      .mockResolvedValueOnce(new Response(Buffer.from("tampered bytes"), { status: 200 }));
    vi.stubGlobal("fetch", fetchMock);
    const service = new GoogleDriveStorageService();

    await expect(service.verifyComplaintEvidenceFile(driveFileId, evidenceId, sha256, bytes.length)).resolves.toBe(false);
  });

  it("requires owner metadata before deleting a member media object", async () => {
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ access_token: "synthetic-access-token", expires_in: 3600 }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        id: driveFileId,
        trashed: false,
        appProperties: { sakhiAccountId: accountId, sakhiPurpose: "post" },
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(null, { status: 204 }));
    vi.stubGlobal("fetch", fetchMock);
    const service = new GoogleDriveStorageService();

    await expect(service.deleteMemberMediaFile(driveFileId, accountId)).resolves.toBeUndefined();
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });
});
