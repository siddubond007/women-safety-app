import { Module } from "@nestjs/common";
import { PrismaModule } from "../database/prisma.module.js";
import { StagingTestAdminController } from "./staging-test-admin.controller.js";
import { StagingTestAdminService } from "./staging-test-admin.service.js";

@Module({
  imports: [PrismaModule],
  controllers: [StagingTestAdminController],
  providers: [StagingTestAdminService],
})
export class StagingTestAdminModule {}
