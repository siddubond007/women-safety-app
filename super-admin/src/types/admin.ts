export type MetricTone = "rose" | "violet" | "amber" | "blue" | "green";

export interface DashboardMetric {
  id: string;
  label: string;
  value: string;
  detail: string;
  delta?: string;
  direction?: "up" | "down" | "neutral";
  tone: MetricTone;
  icon: "members" | "verified" | "pending" | "activity";
}

export interface Indicator {
  id: string;
  label: string;
  value: string;
  detail: string;
}

export interface AttentionItem {
  id: string;
  title: string;
  description: string;
  age: string;
  severity: "urgent" | "high" | "normal";
  route: string;
  icon: "verification" | "report" | "complaint";
}

export interface QueueRow {
  id: string;
  reference: string;
  category: string;
  owner: string;
  status: string;
  age: string;
  severity: "urgent" | "high" | "normal";
  route: string;
}

export interface TrendPoint {
  label: string;
  value: number;
}

export interface IntegrationPlaceholder {
  id: string;
  name: string;
  description: string;
}

export interface DashboardSnapshot {
  metrics: DashboardMetric[];
  indicators: Indicator[];
  trend: TrendPoint[];
  attentionItems: AttentionItem[];
  queueRows: QueueRow[];
  integrations: IntegrationPlaceholder[];
  dataNotice: string;
}