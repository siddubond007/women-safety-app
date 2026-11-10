import { Injectable } from "@nestjs/common";
import type { OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../generated/prisma/client.js";
import type { Prisma } from "../generated/prisma/client.js";
import type { AuthenticatedMemberIdentity } from "../auth/member-identity.js";
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
      // Keep PostgreSQL DateTime encoding/decoding consistent with UTC.
      options: "-c timezone=UTC",
      max: 10,
      connectionTimeoutMillis: 5_000,
      idleTimeoutMillis: 30_000,
    });
    super({ adapter });
  }

  /**
   * Run member-owned database work with a transaction-local PostgreSQL identity.
   * The setting and all protected queries share the same Prisma transaction/connection.
   */
  async withMemberIdentity<T>(
    identity: AuthenticatedMemberIdentity,
    operation: (tx: Prisma.TransactionClient) => Promise<T>,
  ): Promise<T> {
    if (
      !identity ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        identity.accountId,
      ) ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        identity.sessionId,
      )
    ) {
      throw new Error("A valid authenticated member identity is required.");
    }

    return this.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT set_config('app.account_id', ${identity.accountId}, true)`;
      return operation(tx);
    });
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
