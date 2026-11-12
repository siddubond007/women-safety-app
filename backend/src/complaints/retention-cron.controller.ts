import {
  Controller,
  HttpCode,
  Post,
  Headers,
  Param,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { timingSafeEqual } from "node:crypto";
import { ComplaintEvidenceRetentionWorker } from "./complaint-evidence-retention.worker.js";

/** Server-to-server trigger used by the free GitHub Actions scheduled workflow. */
@Controller("internal/retention")
export class RetentionCronController {
  constructor(private readonly worker: ComplaintEvidenceRetentionWorker) {}

  private assertSchedulerCredential(authorization?: string): void {
    if (
      process.env.SAKHI_ENV !== "staging" ||
      process.env.NODE_ENV !== "production" ||
      process.env.SAKHI_EVIDENCE_RETENTION_WORKER_ENABLED !== "true"
    ) {
      throw new ServiceUnavailableException("The staging retention scheduler is not enabled.");
    }
    const expected = process.env.SAKHI_EVIDENCE_RETENTION_CRON_TOKEN?.trim() ?? "";
    if (expected.length < 32) {
      throw new ServiceUnavailableException("The retention scheduler authentication token is not configured.");
    }
    const supplied = authorization?.startsWith("Bearer ") ? authorization.slice(7).trim() : "";
    const expectedBytes = Buffer.from(expected, "utf8");
    const suppliedBytes = Buffer.from(supplied, "utf8");
    if (suppliedBytes.length !== expectedBytes.length || !timingSafeEqual(expectedBytes, suppliedBytes)) {
      throw new UnauthorizedException("The retention scheduler credential is invalid.");
    }
  }

  @Post("run")
  @HttpCode(200)
  async run(@Headers("authorization") authorization?: string) {
    this.assertSchedulerCredential(authorization);
    const complaintEvidence = await this.worker.runOnce();
    const accountDeletion = await this.worker.runAccountDeletionOnce();
    return {
      executedAt: new Date().toISOString(),
      complaintEvidence,
      accountDeletion,
    };
  }

  /**
   * Narrow test-only runner. It never invokes the global complaint sweep and
   * the worker verifies the fixture's immutable synthetic audit marker before
   * selecting only that fixture account's pending deletion request.
   */
  @Post("synthetic/:fixtureId/run")
  @HttpCode(200)
  async runSyntheticFixture(
    @Param("fixtureId") fixtureId: string,
    @Headers("authorization") authorization?: string,
  ) {
    this.assertSchedulerCredential(authorization);
    if (process.env.SAKHI_SYNTHETIC_FIXTURE_ENABLED !== "true") {
      throw new ServiceUnavailableException("Synthetic staging fixtures are disabled.");
    }
    const accountDeletion = await this.worker.runAccountDeletionOnce(fixtureId);
    return {
      executedAt: new Date().toISOString(),
      scope: "single_audited_synthetic_member_fixture",
      fixtureId,
      accountDeletion,
    };
  }
}
