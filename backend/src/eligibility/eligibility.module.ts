import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { EligibilityController } from "./eligibility.controller.js";
import { EligibilityService } from "./eligibility.service.js";
import {
  ELIGIBILITY_PROVIDER,
  UnconfiguredEligibilityProviderAdapter,
} from "./eligibility-provider.js";

@Module({
  imports: [AuthModule],
  controllers: [EligibilityController],
  providers: [
    EligibilityService,
    {
      provide: ELIGIBILITY_PROVIDER,
      useClass: UnconfiguredEligibilityProviderAdapter,
    },
  ],
})
export class EligibilityModule {}
