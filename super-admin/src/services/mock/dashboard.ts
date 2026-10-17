import type {
  AttentionItem,
  DashboardMetric,
  Indicator,
  IntegrationPlaceholder,
  QueueRow,
  TrendPoint,
} from "../../types/admin";

// All records in this file are fictional UI examples. They are never fetched
// from or written to a production backend.
export const dashboardMetrics: DashboardMetric[] = [
  {
    id: "members",
    label: "Registered members",
    value: "12,840",
    detail: "All-time registrations",
    delta: "+8.4%",
    direction: "up",
    tone: "rose",
    icon: "members",
  },
  {
    id: "verified",
    label: "Verified members",
    value: "9,462",
    detail: "Sample verification records",
    delta: "+5.2%",
    direction: "up",
    tone: "green",
    icon: "verified",
  },
  {
    id: "pending",
    label: "Pending verification",
    value: "284",
    detail: "Sample queue size",
    delta: "26 aging",
    direction: "neutral",
    tone: "amber",
    icon: "pending",
  },
  {
    id: "active",
    label: "Monthly active users",
    value: "6,280",
    detail: "Illustrative 30-day count",
    delta: "+3.1%",
    direction: "up",
    tone: "violet",
    icon: "activity",
  },
];

export const dashboardIndicators: Indicator[] = [
  { id: "businesses", label: "Business pages", value: "318", detail: "247 active · 19 pending review" },
  { id: "content", label: "Reported content", value: "42", detail: "Sample reports awaiting review" },
  { id: "complaints", label: "Open complaints", value: "18", detail: "7 marked high priority" },
  { id: "sos", label: "SOS events", value: "37", detail: "Illustrative count for selected period" },
  { id: "media", label: "Posts & media uploads", value: "2,416", detail: "Illustrative activity total" },
  { id: "closed", label: "Closed complaints", value: "126", detail: "Illustrative resolved count" },
  { id: "failures", label: "Verification failures", value: "13", detail: "Sample provider failure cases" },
  { id: "alerts", label: "Integration alerts", value: "4", detail: "Demo alerts; no live integrations" },
];

export const weeklyTrend: TrendPoint[] = [
  { label: "Mon", value: 46 },
  { label: "Tue", value: 59 },
  { label: "Wed", value: 52 },
  { label: "Thu", value: 72 },
  { label: "Fri", value: 65 },
  { label: "Sat", value: 83 },
  { label: "Sun", value: 76 },
];

export const attentionItems: AttentionItem[] = [
  {
    id: "verify-aging",
    title: "Verification queue needs review",
    description: "26 sample requests are older than the review target",
    age: "Oldest: 19h",
    severity: "high",
    route: "/verification",
    icon: "verification",
  },
  {
    id: "content-reports",
    title: "Reported content awaiting triage",
    description: "12 sample reports are marked high priority",
    age: "Oldest: 6h",
    severity: "high",
    route: "/moderation",
    icon: "report",
  },
  {
    id: "complaint-escalation",
    title: "Complaint escalation review",
    description: "3 sample cases need a supervisor decision",
    age: "Oldest: 2h",
    severity: "urgent",
    route: "/complaints",
    icon: "complaint",
  },
];

export const queueRows: QueueRow[] = [
  {
    id: "q-101",
    reference: "VER-0101",
    category: "Eligibility review",
    owner: "Verification team",
    status: "Pending review",
    age: "19h",
    severity: "high",
    route: "/verification",
  },
  {
    id: "q-102",
    reference: "REP-0238",
    category: "Reported post",
    owner: "Trust & Safety",
    status: "Unassigned",
    age: "6h",
    severity: "high",
    route: "/moderation",
  },
  {
    id: "q-103",
    reference: "CMP-0042",
    category: "Member complaint",
    owner: "Complaints team",
    status: "Escalated",
    age: "2h",
    severity: "urgent",
    route: "/complaints",
  },
];

export const integrationPlaceholders: IntegrationPlaceholder[] = [
  { id: "api", name: "Backend API", description: "Health checks not configured" },
  { id: "notifications", name: "Push / SMS / OTP", description: "Provider credentials not configured" },
  { id: "maps", name: "Maps & location", description: "Provider not connected" },
  { id: "identity", name: "Identity verification", description: "Provider awaits approval and integration" },
];

export const demoDataNotice =
  "Fictional sample data for UI review only. It does not represent live Sakhi members or operational status.";