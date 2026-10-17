import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { PrismaModule } from "../database/prisma.module.js";
import { Module2Controller } from "./module2.controller.js";
import { Module2Service } from "./module2.service.js";

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [Module2Controller],
  providers: [Module2Service],
})
export class Module2Module {}
