import { Injectable } from "@nestjs/common";
import type { OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../generated/prisma/client.js";
import {
  assertSakhiDatabaseTarget,
  parseSakhiEnvironment,
} from "../config/database-target.js";

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleDestroy {
  constructor(config: ConfigService) {
    const environment = parseSakhiEnvironment(config.get<string>("SAKHI_ENV"));
    const connectionString = config.getOrThrow<string>(
      "SAKHI_APP_DATABASE_URL",
    );
    assertSakhiDatabaseTarget(connectionString, "app", environment);
    const adapter = new PrismaPg({
      connectionString,
      max: 10,
      connectionTimeoutMillis: 5_000,
      idleTimeoutMillis: 30_000,
    });
    super({ adapter });
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
