import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { PrismaModule } from "../database/prisma.module.js";
import { StorageModule } from "../storage/storage.module.js";
import { ComplaintsController } from "./complaints.controller.js";
import { ComplaintsService } from "./complaints.service.js";
import { ComplaintEvidenceRetentionWorker } from "./complaint-evidence-retention.worker.js";

@Module({
  imports: [PrismaModule, AuthModule, StorageModule],
  controllers: [ComplaintsController],
  providers: [ComplaintsService, ComplaintEvidenceRetentionWorker],
  exports: [ComplaintsService],
})
export class ComplaintsModule {}
