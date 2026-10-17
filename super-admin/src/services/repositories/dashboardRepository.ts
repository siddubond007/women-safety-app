import { ADMIN_DATA_SOURCE } from "../../config/dataSource";
import type { DashboardSnapshot } from "../../types/admin";
import { mockDashboardRepository } from "../mock/mockDashboardRepository";

export interface DashboardRepository {
  getSnapshot(): Promise<DashboardSnapshot>;
}

/**
 * Central repository selector. An API implementation must not be added until
 * backend routes and response contracts are approved and actually available.
 */
const repositories: Record<typeof ADMIN_DATA_SOURCE, DashboardRepository> = {
  mock: mockDashboardRepository,
};

export function getDashboardRepository(): DashboardRepository {
  return repositories[ADMIN_DATA_SOURCE];
}
