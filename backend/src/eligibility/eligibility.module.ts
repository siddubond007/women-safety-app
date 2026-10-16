import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { EligibilityController } from "./eligibility.controller.js";
import { EligibilityService } from "./eligibility.service.js";
import { EligibilitySessionExpiryWorker } from "./eligibility-session-expiry.worker.js";
import {
  ELIGIBILITY_PROVIDER,
  UnconfiguredEligibilityProviderAdapter,
} from "./eligibility-provider.js";
import { VerifiedEligibilityGuard } from "./verified-eligibility.guard.js";

@Module({
  imports: [AuthModule],
  controllers: [EligibilityController],
  providers: [
    EligibilityService,
    EligibilitySessionExpiryWorker,
    VerifiedEligibilityGuard,
    {
      provide: ELIGIBILITY_PROVIDER,
      useClass: UnconfiguredEligibilityProviderAdapter,
    },
  ],
  exports: [VerifiedEligibilityGuard],
})
export class EligibilityModule {}
