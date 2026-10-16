import { Module } from "@nestjs/common";
import { PrismaModule } from "../database/prisma.module.js";
import { AuthController } from "./auth.controller.js";
import { AuthenticationService } from "./auth.service.js";

@Module({
  imports: [PrismaModule],
  controllers: [AuthController],
  providers: [AuthenticationService],
  exports: [AuthenticationService],
})
export class AuthModule {}
