import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { EligibilityController } from "./eligibility.controller.js";
import { EligibilityService } from "./eligibility.service.js";
import { DecentroKycService } from "./decentro-kyc.service.js";

@Module({
  imports: [AuthModule],
  controllers: [EligibilityController],
  providers: [EligibilityService, DecentroKycService],
})
export class EligibilityModule {}
