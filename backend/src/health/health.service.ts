import { Injectable, ServiceUnavailableException } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service.js";

@Injectable()
export class HealthService {
  constructor(private readonly prisma: PrismaService) {}

  live(): { status: "ok" } {
    return { status: "ok" };
  }

  async ready(): Promise<{
    status: "ready";
    dependencies: { database: "ok" };
  }> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { status: "ready", dependencies: { database: "ok" } };
    } catch {
      // Never send database hostnames, credentials, SQL, or driver errors to clients.
      throw new ServiceUnavailableException("Service temporarily unavailable");
    }
  }
}
