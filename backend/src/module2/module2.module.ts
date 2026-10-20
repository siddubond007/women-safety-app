import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module.js";
import { StorageModule } from "../storage/storage.module.js";
import { Module2Controller } from "./module2.controller.js";
import { Module2Service } from "./module2.service.js";
import { GoogleDriveIntegrationController } from "./google-drive-integration.controller.js";
import { GoogleDriveStorageService } from "./google-drive-storage.service.js";

@Module({
  imports: [AuthModule, StorageModule],
  controllers: [Module2Controller, GoogleDriveIntegrationController],
  providers: [Module2Service, GoogleDriveStorageService],
  exports: [Module2Service, GoogleDriveStorageService],
})
export class Module2Module {}
