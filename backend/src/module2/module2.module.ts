import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { Module2Controller } from "./module2.controller.js";
import { Module2Service } from "./module2.service.js";

@Module({
  imports: [AuthModule],
  controllers: [Module2Controller],
  providers: [Module2Service],
  exports: [Module2Service],
})
export class Module2Module {}
