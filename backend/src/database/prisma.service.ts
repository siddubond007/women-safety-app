import { Injectable } from "@nestjs/common";
import type { OnModuleDestroy } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../generated/prisma/client.js";
import type { Prisma } from "../generated/prisma/client.js";
import type { AuthenticatedMemberIdentity } from "../auth/member-identity.js";
import {
  databaseRequestIdentityStorage,
  databaseTransactionStorage,
} from "./database-request-identity.context.js";
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

    // Every Prisma delegate query in an authenticated request runs inside a
    // transaction with transaction-local member/admin identity. This closes
    // the gap where only selected service methods opted into RLS explicitly.
    const target = this;
    const queryMethods = new Set([
      "findUnique", "findUniqueOrThrow", "findFirst", "findFirstOrThrow",
      "findMany", "create", "createMany", "createManyAndReturn",
      "update", "updateMany", "updateManyAndReturn", "upsert",
      "delete", "deleteMany", "count", "aggregate", "groupBy",
    ]);
    const proxy = new Proxy(this, {
      get(prismaTarget, property, receiver) {
        if (property === "$transaction") {
          const original = Reflect.get(prismaTarget, property, prismaTarget) as Function;
          return (operation: unknown, options?: unknown) => {
            const activeTransaction = databaseTransactionStorage.getStore() as Prisma.TransactionClient | undefined;
            if (activeTransaction) {
              if (typeof operation === "function") return operation(activeTransaction);
              return original.call(prismaTarget, operation, options);
            }
            if (Array.isArray(operation)) {
              if (databaseRequestIdentityStorage.getStore()) {
                throw new Error("Array-form Prisma transactions are not supported inside an RLS-scoped request; use callback transactions.");
              }
              return original.call(prismaTarget, operation, options);
            }
            if (typeof operation !== "function") {
              return original.call(prismaTarget, operation, options);
            }
            const identity = databaseRequestIdentityStorage.getStore();
            return original.call(prismaTarget, async (tx: Prisma.TransactionClient) => {
              if (identity) {
                await tx.$queryRaw`SELECT
                  set_config('app.account_id', ${identity.accountId ?? ""}, true),
                  set_config('app.session_id', ${identity.sessionId ?? ""}, true),
                  set_config('app.admin_staff_id', ${identity.adminStaffId ?? ""}, true),
                  set_config('app.admin_role', ${identity.adminRole ?? ""}, true),
                  set_config('app.auth_lookup', ${identity.authLookup ? "true" : "false"}, true),
                  set_config('app.username_lookup', ${identity.usernameLookup ? "true" : "false"}, true),
                  set_config('app.system_job', 'false', true),
                  set_config('app.auth_session_digest', '', true),
                  set_config('app.notification_recipient_id', '', true)`;
              }
              return databaseTransactionStorage.run(tx, () => operation(tx));
            }, options);
          };
        }

        const value = Reflect.get(prismaTarget, property, receiver);
        if (
          typeof property === "string" &&
          value !== null && typeof value === "object" &&
          typeof (value as Record<string, unknown>).findMany === "function"
        ) {
          return new Proxy(value, {
            get(delegate, method) {
              const methodValue = Reflect.get(delegate, method, delegate);
              if (typeof method !== "string" || !queryMethods.has(method) || typeof methodValue !== "function") {
                return methodValue;
              }
              return (...args: unknown[]) => {
                const activeTransaction = databaseTransactionStorage.getStore() as Prisma.TransactionClient | undefined;
                if (activeTransaction) {
                  const transactionDelegate = (activeTransaction as unknown as Record<string, any>)[property];
                  return transactionDelegate[method](...args);
                }
                const identity = databaseRequestIdentityStorage.getStore();
                const authSessionDigest = property === "authSession" && method === "findUnique"
                  ? String((args[0] as any)?.where?.tokenDigest ?? "")
                  : "";
                if ((!identity || (!identity.accountId && !identity.adminStaffId && !identity.authLookup && !identity.usernameLookup)) && !authSessionDigest) {
                  return methodValue.apply(delegate, args);
                }
                const transaction = Reflect.get(prismaTarget, "$transaction", prismaTarget) as Function;
                return transaction.call(prismaTarget, async (tx: Prisma.TransactionClient) => {
                  await tx.$queryRaw`SELECT
                    set_config('app.account_id', ${identity?.accountId ?? ""}, true),
                    set_config('app.session_id', ${identity?.sessionId ?? ""}, true),
                    set_config('app.admin_staff_id', ${identity?.adminStaffId ?? ""}, true),
                    set_config('app.admin_role', ${identity?.adminRole ?? ""}, true),
                    set_config('app.auth_lookup', ${identity?.authLookup ? "true" : "false"}, true),
                    set_config('app.username_lookup', ${identity?.usernameLookup ? "true" : "false"}, true),
                    set_config('app.system_job', 'false', true),
                    set_config('app.auth_session_digest', ${authSessionDigest}, true),
                    set_config('app.notification_recipient_id', '', true)`;
                  return databaseTransactionStorage.run(tx, () =>
                    (tx as unknown as Record<string, any>)[property][method](...args),
                  );
                });
              };
            },
          });
        }
        return value;
      },
    });
    return proxy as this;
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
      await tx.$queryRaw`SELECT
        set_config('app.account_id', ${identity.accountId}, true),
        set_config('app.system_job', 'false', true)`;
      return operation(tx);
    });
  }

  /**
   * Internal notification delivery context. A member endpoint may create a
   * notification for the recipient of a validated interaction without gaining
   * general read access to that member's private records.
   */
  async withNotificationRecipientIdentity<T>(
    recipientAccountId: string,
    operation: (tx: Prisma.TransactionClient) => Promise<T>,
  ): Promise<T> {
    if (!/^[0-9a-f-]{36}$/i.test(recipientAccountId)) {
      throw new Error("A valid notification recipient account ID is required.");
    }
    const identity = databaseRequestIdentityStorage.getStore();
    if (!identity || (!identity.accountId && !identity.adminStaffId)) {
      throw new Error("Notification delivery requires a validated member or admin request identity.");
    }
    return this.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT set_config('app.notification_recipient_id', ${recipientAccountId}, true)`;
      return operation(tx);
    });
  }

  /** Internal scheduled-job identity. Never expose this helper through a member/admin controller. */
  async withSystemAdminIdentity<T>(
    operation: (tx: Prisma.TransactionClient) => Promise<T>,
  ): Promise<T> {
    return this.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT
        set_config('app.account_id', '', true),
        set_config('app.session_id', '', true),
        set_config('app.admin_staff_id', '00000000-0000-4000-8000-000000000001', true),
        set_config('app.admin_role', 'SUPER_ADMIN', true),
        set_config('app.auth_lookup', 'false', true),
        set_config('app.username_lookup', 'false', true),
        set_config('app.system_job', 'true', true),
        set_config('app.auth_session_digest', '', true),
        set_config('app.notification_recipient_id', '', true)`;
      return operation(tx);
    });
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
