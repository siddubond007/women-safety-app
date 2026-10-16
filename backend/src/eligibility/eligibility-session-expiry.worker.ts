import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { EligibilityService } from "./eligibility.service.js";

export const ELIGIBILITY_SESSION_EXPIRY_INTERVAL_MS = 60_000;

/**
 * Periodically expires abandoned eligibility sessions. The sweep is
 * idempotent and account-row locked, so multiple app instances may run it
 * safely. Provider timeouts remain lifecycle events, never eligibility
 * decisions.
 */
@Injectable()
export class EligibilitySessionExpiryWorker
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(EligibilitySessionExpiryWorker.name);
  private timer: ReturnType<typeof setInterval> | undefined;
  private running = false;

  constructor(private readonly eligibility: EligibilityService) {}

  onModuleInit(): void {
    // Also sweep immediately after startup to recover sessions that expired
    // while the application process was stopped.
    void this.runSweep();
    this.timer = setInterval(() => {
      void this.runSweep();
    }, ELIGIBILITY_SESSION_EXPIRY_INTERVAL_MS);
    this.timer.unref?.();
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = undefined;
    }
  }

  private async runSweep(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      await this.eligibility.expireStaleVerificationSessions();
    } catch {
      // Keep logs free of session/account data and retry on the next interval.
      this.logger.error(
        "Eligibility session expiry sweep failed; it will be retried.",
      );
    } finally {
      this.running = false;
    }
  }
}
