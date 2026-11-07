import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { PrismaModule } from "../database/prisma.module.js";
import { ComplaintsController } from "./complaints.controller.js";
import { ComplaintsService } from "./complaints.service.js";

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [ComplaintsController],
  providers: [ComplaintsService],
  exports: [ComplaintsService],
})
export class ComplaintsModule {}
