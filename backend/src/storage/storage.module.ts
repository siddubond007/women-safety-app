import { Global, Module } from "@nestjs/common";
import { GoogleDriveStorageService } from "../module2/google-drive-storage.service.js";

@Global()
@Module({
  providers: [GoogleDriveStorageService],
  exports: [GoogleDriveStorageService],
})
export class StorageModule {}
