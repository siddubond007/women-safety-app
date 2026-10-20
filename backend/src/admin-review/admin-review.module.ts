import { Module } from "@nestjs/common";
import { StorageModule } from "../storage/storage.module.js";
import { AdminReviewController } from "./admin-review.controller.js";
import { AdminReviewService } from "./admin-review.service.js";

@Module({
  imports: [StorageModule],
  controllers: [AdminReviewController],
  providers: [AdminReviewService],
})
export class AdminReviewModule {}
