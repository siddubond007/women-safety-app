import { Module } from "@nestjs/common";
import { PrismaModule } from "../database/prisma.module.js";
import { AdminMfaService } from "./admin-mfa.service.js";
import { AdminSessionService } from "./admin-session.service.js";
import { AdminStaffSessionGuard } from "./admin-staff-session.guard.js";

@Module({
  imports: [PrismaModule],
  providers: [AdminSessionService, AdminMfaService, AdminStaffSessionGuard],
  exports: [AdminSessionService, AdminMfaService, AdminStaffSessionGuard],
})
export class AdminSecurityModule {}
