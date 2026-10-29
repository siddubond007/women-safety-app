import { useCallback, useEffect, useState } from "react";
import {
  AlertTriangle,
  Award,
  Building2,
  CheckCircle2,
  MessageSquare,
  Plus,
  RefreshCw,
  ShieldAlert,
  Sparkles,
} from "lucide-react";
import { StatusPill } from "../components/StatusPill";
import { SakhiQuoteLoader } from "../components/SakhiQuoteLoader";
import { adminApi } from "../services/api/adminApi";

interface BusinessListingRecord {
  id: string;
  businessCode: string;
  businessName: string;
  ownerAccountId: string | null;
  ownerDisplayName: string;
  category: string;
  city: string;
  serviceArea?: string | null;
  priceRange?: string | null;
  hidePhoneNumber?: boolean;
  productsServices?: Array<Record<string, unknown>>;
  enquiriesCount?: number;
  description: string;
  contactPhone: string | null;
  websiteOrInstagram: string | null;
  approvalStatus: "PENDING_APPROVAL" | "APPROVED" | "SUSPENDED" | "REJECTED";
  verificationBadgeStatus:
    | "NONE"
    | "PENDING_BADGE"
    | "VERIFIED_WOMAN_OWNED"
    | "REVOKED";
  isFeatured: boolean;
  isReportedFraudulent: boolean;
  reportReason: string | null;
  reviewedBy: string | null;
  reviewNotes: string | null;
  createdAt: string;
  updatedAt: string;
}

interface BusinessDirectoryPayload {
  metrics: {
    totalBusinesses: number;
    pendingApprovalCount: number;
    approvedCount: number;
    verifiedBadgeCount: number;
    pendingBadgeCount: number;
    reportedFraudulentCount: number;
    featuredCount: number;
  };
  categories: string[];
  businesses: BusinessListingRecord[];
}

function formatEnumLabel(val: string): string {
  return val
    .replace(/_/g, " ")
    .toLowerCase()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

export function BusinessManagementPage() {
  const [data, setData] = useState<BusinessDirectoryPayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");

  // Add Business Listing State (Module 6 SRS Section 8.1-8.5)
  const [businessName, setBusinessName] = useState("");
  const [ownerDisplayName, setOwnerDisplayName] = useState("");
  const [category, setCategory] = useState("Fashion & Clothing");
  const [city, setCity] = useState("Bengaluru");
  const [serviceArea, setServiceArea] = useState("Pan-India & Local City");
  const [priceRange, setPriceRange] = useState("₹₹");
  const [description, setDescription] = useState("");
  const [website, setWebsite] = useState("");

  const loadBusinesses = useCallback(async () => {
    try {
      const res = await adminApi<BusinessDirectoryPayload>(
        "/admin-review/businesses",
      );
      setData(res);
      if (res.categories.length > 0) {
        setCategory((current) => current || res.categories[0]);
      }
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Could not load Business & Marketplace Directory.",
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void Promise.resolve().then(() => loadBusinesses());
  }, [loadBusinesses]);

  async function handleCreateBusiness() {
    if (businessName.trim().length < 3) {
      setError("Enter a business name of at least 3 characters.");
      return;
    }
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi("/admin-review/businesses", {
        method: "POST",
        body: {
          businessName: businessName.trim(),
          ownerDisplayName:
            ownerDisplayName.trim() || "Verified Sakhi Entrepreneur",
          category,
          city: city.trim() || "Bengaluru",
          serviceArea: serviceArea.trim() || "Pan-India & Local City",
          priceRange,
          description:
            description.trim() ||
            "Verified women-owned business on Sakhi Marketplace.",
          websiteOrInstagram: website.trim() || undefined,
        },
      });
      setBusinessName("");
      setOwnerDisplayName("");
      setDescription("");
      setWebsite("");
      setNotice("Saved Module 6 business listing to PostgreSQL directory.");
      await loadBusinesses();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to save business listing.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleReviewAction(
    biz: BusinessListingRecord,
    patch: Record<string, unknown>,
    summaryLabel: string,
  ) {
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi(
        `/admin-review/businesses/${encodeURIComponent(biz.id)}/review`,
        {
          method: "PATCH",
          body: patch,
        },
      );
      setNotice(`${summaryLabel} for ${biz.businessName} (${biz.businessCode}).`);
      await loadBusinesses();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to update business status.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  if (loading && !data) {
    return (
      <SakhiQuoteLoader statusLabel="Loading Module 6 Women-Owned Business & Marketplace Directory..." />
    );
  }

  const metrics = data?.metrics ?? {
    totalBusinesses: 0,
    pendingApprovalCount: 0,
    approvedCount: 0,
    verifiedBadgeCount: 0,
    pendingBadgeCount: 0,
    reportedFraudulentCount: 0,
    featuredCount: 0,
  };
  const categories = data?.categories ?? [
    "Fashion & Clothing",
    "Beauty & Salon Services",
    "Home Baking & Food",
    "Handicrafts & Art",
    "Health & Wellness",
    "Education & Coaching",
    "Freelancing & Digital Services",
    "Fitness & Yoga",
    "Childcare & Parenting",
    "Event Planning & Photography",
  ];
  const businesses = (data?.businesses ?? []).filter((b) => {
    if (statusFilter === "ALL") return true;
    if (statusFilter === "REPORTED") return b.isReportedFraudulent;
    return b.approvalStatus === statusFilter;
  });

  return (
    <div
      className="page-stack"
      style={{ display: "flex", flexDirection: "column", gap: "24px" }}
    >
      <section className="hero-card">
        <div className="hero-copy">
          <div className="eyebrow-row">
            <StatusPill tone="rose">
              MODULE 6 &amp; ROLE 5 • WOMEN-OWNED BUSINESS PAGES (SRS 8 &amp; 12.7)
            </StatusPill>
            <StatusPill tone="green">Live PostgreSQL Directory</StatusPill>
          </div>
          <h1>Women-Owned Business Directory &amp; Badge Governance</h1>
          <p>
            Review and approve women-owned business pages, issue Verified
            Woman-Owned Business badges, curate featured placements, monitor
            customer enquiries, and investigate reported business pages.
          </p>
        </div>
        <div className="hero-actions">
          <button
            className="secondary-button"
            type="button"
            disabled={loading || submitting}
            onClick={() => {
              setLoading(true);
              setError("");
              void loadBusinesses();
            }}
          >
            <RefreshCw size={15} /> {loading ? "Syncing..." : "Refresh Directory"}
          </button>
        </div>
      </section>

      {notice && (
        <div
          className="demo-banner"
          style={{
            background: "#e8f5ed",
            borderColor: "#b8e2c8",
            color: "#1f6e4e",
          }}
        >
          <CheckCircle2 size={18} />
          <div>
            <strong>Marketplace Update Saved</strong>
            <span>{notice}</span>
          </div>
        </div>
      )}
      {error && (
        <div
          className="demo-banner"
          style={{
            background: "#fcebed",
            borderColor: "#f5c2c7",
            color: "#a63b4a",
          }}
        >
          <AlertTriangle size={18} />
          <div>
            <strong>Error</strong>
            <span>{error}</span>
          </div>
        </div>
      )}

      {/* KPI Row */}
      <section
        className="stats-grid"
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
          gap: "18px",
        }}
      >
        <article
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            TOTAL LISTED BUSINESSES
          </span>
          <div
            style={{
              fontSize: "28px",
              fontWeight: 800,
              color: "#31263a",
              marginTop: "8px",
            }}
          >
            {metrics.totalBusinesses}{" "}
            <StatusPill tone="amber">
              {metrics.pendingApprovalCount} Pending
            </StatusPill>
          </div>
        </article>
        <article
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            VERIFIED WOMAN-OWNED BADGES
          </span>
          <div
            style={{
              fontSize: "28px",
              fontWeight: 800,
              color: "#631d76",
              marginTop: "8px",
            }}
          >
            {metrics.verifiedBadgeCount}{" "}
            <StatusPill tone="green">
              {metrics.featuredCount} Featured
            </StatusPill>
          </div>
        </article>
        <article
          style={{
            background: "#fff",
            padding: "20px",
            borderRadius: "16px",
            border: "1px solid #eee7ee",
          }}
        >
          <span style={{ fontSize: "12px", color: "#877b8b", fontWeight: 700 }}>
            REPORTED / FRAUD QUEUE
          </span>
          <div
            style={{
              fontSize: "28px",
              fontWeight: 800,
              color: "#a63b4a",
              marginTop: "8px",
            }}
          >
            {metrics.reportedFraudulentCount}{" "}
            <StatusPill tone="urgent">Trust &amp; Safety</StatusPill>
          </div>
        </article>
      </section>

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "1fr 1.45fr",
          gap: "22px",
          alignItems: "start",
        }}
      >
        {/* Left: Register / Onboard Business Page */}
        <div
          style={{
            background: "#fff",
            borderRadius: "18px",
            border: "1px solid #eee7ee",
            padding: "22px",
          }}
        >
          <h3 style={{ margin: "0 0 12px 0", fontSize: "17px" }}>
            <Building2
              size={17}
              style={{ verticalAlign: "middle", marginRight: "6px" }}
            />
            Register Women-Owned Business Listing
          </h3>
          <div
            style={{ display: "flex", flexDirection: "column", gap: "12px" }}
          >
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Business Name *
              <input
                value={businessName}
                onChange={(e) => setBusinessName(e.target.value)}
                placeholder="e.g., Zari & Lotus Handloom Studio"
                style={{
                  width: "100%",
                  marginTop: "4px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Founder / Member Name
              <input
                value={ownerDisplayName}
                onChange={(e) => setOwnerDisplayName(e.target.value)}
                placeholder="e.g., Ananya Sharma"
                style={{
                  width: "100%",
                  marginTop: "4px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Business Category (SRS 8.3)
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                style={{
                  width: "100%",
                  marginTop: "4px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              >
                {categories.map((cat) => (
                  <option key={cat} value={cat}>
                    {cat}
                  </option>
                ))}
              </select>
            </label>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "10px" }}>
              <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                City / Neighbourhood
                <input
                  value={city}
                  onChange={(e) => setCity(e.target.value)}
                  placeholder="Bengaluru"
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                />
              </label>
              <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
                Price Tier
                <select
                  value={priceRange}
                  onChange={(e) => setPriceRange(e.target.value)}
                  style={{
                    width: "100%",
                    marginTop: "4px",
                    padding: "10px 12px",
                    borderRadius: "10px",
                    border: "1px solid #dcd0e0",
                  }}
                >
                  <option value="₹">₹ (Budget Friendly)</option>
                  <option value="₹₹">₹₹ (Moderate)</option>
                  <option value="₹₹₹">₹₹₹ (Premium)</option>
                  <option value="₹₹₹₹">₹₹₹₹ (Luxury / Bespoke)</option>
                </select>
              </label>
            </div>
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Service Area
              <input
                value={serviceArea}
                onChange={(e) => setServiceArea(e.target.value)}
                placeholder="Pan-India & Local City"
                style={{
                  width: "100%",
                  marginTop: "4px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
            <label style={{ fontSize: "12.5px", fontWeight: 700 }}>
              Description &amp; Offerings
              <textarea
                rows={2}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                placeholder="Describe services, products, and women-led credentials..."
                style={{
                  width: "100%",
                  marginTop: "4px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>
            <button
              className="button button--secondary"
              type="button"
              disabled={submitting}
              onClick={() => void handleCreateBusiness()}
              style={{
                padding: "12px",
                borderRadius: "999px",
                border: 0,
                background: "#631d76",
                color: "#fff",
                fontWeight: 700,
                cursor: "pointer",
              }}
            >
              <Plus size={15} style={{ verticalAlign: "middle" }} /> Add Business
              to Queue
            </button>
          </div>
        </div>

        {/* Right: Approval, Verification Badge & Fraud Queue */}
        <div
          style={{
            background: "#fff",
            borderRadius: "18px",
            border: "1px solid #eee7ee",
            padding: "22px",
          }}
        >
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              flexWrap: "wrap",
              gap: "10px",
              marginBottom: "16px",
            }}
          >
            <h3 style={{ margin: 0, fontSize: "17px" }}>
              Business Directory &amp; Approval Queue ({businesses.length})
            </h3>
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              style={{
                padding: "8px 12px",
                borderRadius: "10px",
                border: "1px solid #dcd0e0",
                fontWeight: 600,
                fontSize: "13px",
              }}
            >
              <option value="ALL">All Listings</option>
              <option value="PENDING_APPROVAL">Pending Approval</option>
              <option value="APPROVED">Approved</option>
              <option value="SUSPENDED">Suspended</option>
              <option value="REPORTED">Reported / Fraud Flagged</option>
            </select>
          </div>

          {businesses.length === 0 ? (
            <div
              style={{
                padding: "28px 20px",
                textAlign: "center",
                background: "#fdf9fc",
                borderRadius: "14px",
                border: "1px dashed #dcc8e6",
              }}
            >
              <strong style={{ display: "block", color: "#52345f" }}>
                No Business Listings Found
              </strong>
              <p
                style={{
                  margin: "6px 0 0 0",
                  fontSize: "13px",
                  color: "#6e6275",
                }}
              >
                Register a business on the left or sync from verified member
                business profiles.
              </p>
            </div>
          ) : (
            <div
              style={{ display: "flex", flexDirection: "column", gap: "12px" }}
            >
              {businesses.map((biz) => {
                const catalogCount = Array.isArray(biz.productsServices)
                  ? biz.productsServices.length
                  : 0;
                return (
                  <div
                    key={biz.id}
                    style={{
                      padding: "16px",
                      borderRadius: "14px",
                      border: "1px solid #eee7ee",
                      background: biz.isReportedFraudulent ? "#fff8f8" : "#fff",
                    }}
                  >
                    <div
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        alignItems: "center",
                        flexWrap: "wrap",
                        gap: "8px",
                        marginBottom: "6px",
                      }}
                    >
                      <div>
                        <strong style={{ fontSize: "15px" }}>
                          {biz.businessName} ({biz.businessCode})
                        </strong>
                        <div style={{ fontSize: "12px", color: "#6e6275" }}>
                          Founder: {biz.ownerDisplayName} • {biz.category} •{" "}
                          {biz.city}
                          {biz.priceRange ? ` • ${biz.priceRange}` : ""}
                          {biz.serviceArea ? ` • ${biz.serviceArea}` : ""}
                        </div>
                      </div>
                      <div
                        style={{ display: "flex", gap: "6px", flexWrap: "wrap" }}
                      >
                        <StatusPill
                          tone={
                            biz.approvalStatus === "APPROVED"
                              ? "green"
                              : biz.approvalStatus === "SUSPENDED"
                                ? "urgent"
                                : "amber"
                          }
                        >
                          {formatEnumLabel(biz.approvalStatus)}
                        </StatusPill>
                        <StatusPill
                          tone={
                            biz.verificationBadgeStatus === "VERIFIED_WOMAN_OWNED"
                              ? "rose"
                              : "neutral"
                          }
                        >
                          {formatEnumLabel(biz.verificationBadgeStatus)}
                        </StatusPill>
                        {biz.isFeatured && (
                          <StatusPill tone="green">Featured ★</StatusPill>
                        )}
                        {catalogCount > 0 && (
                          <StatusPill tone="neutral">
                            {catalogCount} Offerings
                          </StatusPill>
                        )}
                        {(biz.enquiriesCount ?? 0) > 0 && (
                          <StatusPill tone="amber">
                            <MessageSquare
                              size={11}
                              style={{ verticalAlign: "middle", marginRight: 3 }}
                            />
                            {biz.enquiriesCount} Enquiries
                          </StatusPill>
                        )}
                        {biz.isReportedFraudulent && (
                          <StatusPill tone="urgent">Fraud Flagged</StatusPill>
                        )}
                      </div>
                    </div>
                    <p
                      style={{
                        margin: "0 0 10px 0",
                        fontSize: "13px",
                        color: "#52345f",
                      }}
                    >
                      {biz.description}
                    </p>
                    {biz.reportReason && (
                      <div
                        style={{
                          marginBottom: "10px",
                          padding: "8px 12px",
                          borderRadius: "8px",
                          background: "#fcebed",
                          color: "#a63b4a",
                          fontSize: "12px",
                          fontWeight: 600,
                        }}
                      >
                        Report Reason: {biz.reportReason}
                      </div>
                    )}
                    <div
                      style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}
                    >
                      <button
                        type="button"
                        className="secondary-button"
                        disabled={submitting}
                        onClick={() =>
                          void handleReviewAction(
                            biz,
                            { approvalStatus: "APPROVED" },
                            "Approved listing",
                          )
                        }
                      >
                        <CheckCircle2 size={14} /> Approve Listing
                      </button>
                      <button
                        type="button"
                        className="secondary-button"
                        disabled={submitting}
                        onClick={() =>
                          void handleReviewAction(
                            biz,
                            {
                              verificationBadgeStatus:
                                biz.verificationBadgeStatus ===
                                "VERIFIED_WOMAN_OWNED"
                                  ? "NONE"
                                  : "VERIFIED_WOMAN_OWNED",
                            },
                            "Updated Woman-Owned Verification Badge",
                          )
                        }
                      >
                        <Award size={14} />{" "}
                        {biz.verificationBadgeStatus === "VERIFIED_WOMAN_OWNED"
                          ? "Revoke Badge"
                          : "Grant Woman-Owned Badge"}
                      </button>
                      <button
                        type="button"
                        className="secondary-button"
                        disabled={submitting}
                        onClick={() =>
                          void handleReviewAction(
                            biz,
                            { isFeatured: !biz.isFeatured },
                            "Updated featured placement",
                          )
                        }
                      >
                        <Sparkles size={14} />{" "}
                        {biz.isFeatured ? "Unfeature" : "Feature on App"}
                      </button>
                      <button
                        type="button"
                        className="secondary-button"
                        disabled={submitting}
                        onClick={() =>
                          void handleReviewAction(
                            biz,
                            {
                              approvalStatus:
                                biz.approvalStatus === "SUSPENDED"
                                  ? "APPROVED"
                                  : "SUSPENDED",
                              isReportedFraudulent: !biz.isReportedFraudulent,
                            },
                            "Updated fraud/suspension status",
                          )
                        }
                        style={{ color: "#b4233c" }}
                      >
                        <ShieldAlert size={14} />{" "}
                        {biz.approvalStatus === "SUSPENDED"
                          ? "Restore Business"
                          : "Suspend / Flag Fraud"}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
