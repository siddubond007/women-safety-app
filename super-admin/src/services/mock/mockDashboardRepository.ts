import type { DashboardSnapshot } from "../../types/admin";
import {
  attentionItems,
  dashboardIndicators,
  dashboardMetrics,
  demoDataNotice,
  integrationPlaceholders,
  queueRows,
  weeklyTrend,
} from "./dashboard";
import type { DashboardRepository } from "../repositories/dashboardRepository";

/**
 * Fictional sample-only repository. Every returned record is demo data.
 * This adapter never calls an API or changes a production record.
 */
export const mockDashboardRepository: DashboardRepository = {
  async getSnapshot(): Promise<DashboardSnapshot> {
    return {
      metrics: dashboardMetrics.map((item) => ({ ...item })),
      indicators: dashboardIndicators.map((item) => ({ ...item })),
      trend: weeklyTrend.map((item) => ({ ...item })),
      attentionItems: attentionItems.map((item) => ({ ...item })),
      queueRows: queueRows.map((item) => ({ ...item })),
      integrations: integrationPlaceholders.map((item) => ({ ...item })),
      dataNotice: demoDataNotice,
    };
  },
};
