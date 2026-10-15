import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { EligibilityController } from "./eligibility.controller.js";
import { EligibilityService } from "./eligibility.service.js";

@Module({
  imports: [AuthModule],
  controllers: [EligibilityController],
  providers: [EligibilityService],
})
export class EligibilityModule {}
