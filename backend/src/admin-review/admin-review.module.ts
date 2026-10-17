import { Module } from "@nestjs/common";
import { PrismaModule } from "../database/prisma.module.js";
import { AdminReviewController } from "./admin-review.controller.js";
import { AdminReviewService } from "./admin-review.service.js";

@Module({
  imports: [PrismaModule],
  controllers: [AdminReviewController],
  providers: [AdminReviewService],
})
export class AdminReviewModule {}