import { Module } from "@nestjs/common";
import { PrismaModule } from "../database/prisma.module.js";
import { AdminSecurityModule } from "../admin-security/admin-security.module.js";
import { StagingTestAdminController } from "./staging-test-admin.controller.js";
import { StagingTestAdminService } from "./staging-test-admin.service.js";

@Module({
  imports: [PrismaModule, AdminSecurityModule],
  controllers: [StagingTestAdminController],
  providers: [StagingTestAdminService],
  exports: [StagingTestAdminService],
})
export class StagingTestAdminModule {}
