import { useCallback, useEffect, useState } from "react";
import {
  AlertTriangle,
  Award,
  Building2,
  CheckCircle2,
  Clock,
  Edit3,
  Eye,
  Image as ImageIcon,
  MessageSquare,
  Phone,
  Plus,
  RefreshCw,
  ShieldAlert,
  Sparkles,
  Tag,
  Trash2,
  XCircle,
} from "lucide-react";
import { StatusPill } from "../components/StatusPill";
import { SakhiQuoteLoader } from "../components/SakhiQuoteLoader";
import { adminApi, getAdminApiBaseUrl } from "../services/api/adminApi";

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
  logoAsset?: string | null;
  coverImage?: string | null;
  mediaGallery?: string[];
  businessHours?: Record<string, unknown> | null;
  hidePhoneNumber?: boolean;
  whatsappNumber?: string | null;
  instagramHandle?: string | null;
  productsServices?: Array<Record<string, unknown>>;
  offersAndPosts?: Array<Record<string, unknown>>;
  enquiriesCount?: number;
  viewsCount?: number;
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

interface BusinessEnquiryItem {
  id: string;
  enquiryCode?: string;
  businessId: string;
  businessName?: string;
  senderDisplayName?: string;
  senderUsername?: string;
  subjectOrProduct?: string;
  status?: string;
  messages?: Array<Record<string, unknown>>;
  createdAt?: string;
}

interface BusinessReportItem {
  id: string;
  businessId: string;
  businessName?: string;
  reason: string;
  details?: string | null;
  status?: string;
  createdAt?: string;
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
  enquiries?: BusinessEnquiryItem[];
  reports?: BusinessReportItem[];
}

function formatEnumLabel(val: string): string {
  return val
    .replace(/_/g, " ")
    .toLowerCase()
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function resolveMediaPreviewUrl(rawUrl?: string | null): string | null {
  if (!rawUrl || !rawUrl.trim()) return null;
  const clean = rawUrl.trim();
  if (clean.startsWith("http://") || clean.startsWith("https://")) return clean;
  if (clean.startsWith("/api/v1/")) {
    const base = getAdminApiBaseUrl().replace(/\/api\/v1\/?$/, "");
    return `${base}${clean}`;
  }
  return null;
}

export function BusinessManagementPage() {
  const [data, setData] = useState<BusinessDirectoryPayload | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [statusFilter, setStatusFilter] = useState("ALL");
  const [searchFilter, setSearchFilter] = useState("");
  const [inspectingBiz, setInspectingBiz] =
    useState<BusinessListingRecord | null>(null);
  const [reviewNotesDraft, setReviewNotesDraft] = useState("");
  const [editingInModal, setEditingInModal] = useState(false);
  const [editDraft, setEditDraft] = useState<{
    businessName: string;
    category: string;
    city: string;
    serviceArea: string;
    priceRange: string;
    contactPhone: string;
    whatsappNumber: string;
    websiteOrInstagram: string;
    description: string;
  }>({
    businessName: "",
    category: "",
    city: "",
    serviceArea: "",
    priceRange: "",
    contactPhone: "",
    whatsappNumber: "",
    websiteOrInstagram: "",
    description: "",
  });

  // Add Business Listing State (Module 6 SRS Section 8.1-8.5)
  const [businessName, setBusinessName] = useState("");
  const [ownerDisplayName, setOwnerDisplayName] = useState("");
  const [category, setCategory] = useState("Fashion and clothing");
  const [city, setCity] = useState("Bengaluru");
  const [serviceArea, setServiceArea] = useState("Pan-India & Local City");
  const [priceRange, setPriceRange] = useState("₹500 – ₹2,500");
  const [description, setDescription] = useState("");
  const [website, setWebsite] = useState("");
  const [newCategoryName, setNewCategoryName] = useState("");

  const loadBusinesses = useCallback(async () => {
    try {
      const res = await adminApi<BusinessDirectoryPayload>(
        "/admin-review/businesses",
      );
      setData(res);
      if (res.categories.length > 0) {
        setCategory((current) => current || res.categories[0]);
      }
      setInspectingBiz((prev) => {
        if (!prev) return null;
        return res.businesses.find((b) => b.id === prev.id) ?? null;
      });
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

  async function handleSaveModalEdits() {
    if (!inspectingBiz) return;
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi("/admin-review/businesses", {
        method: "POST",
        body: {
          ...inspectingBiz,
          businessName: editDraft.businessName.trim(),
          category: editDraft.category.trim(),
          city: editDraft.city.trim(),
          serviceArea: editDraft.serviceArea.trim(),
          priceRange: editDraft.priceRange.trim(),
          contactPhone: editDraft.contactPhone.trim() || null,
          whatsappNumber: editDraft.whatsappNumber.trim() || null,
          websiteOrInstagram: editDraft.websiteOrInstagram.trim() || null,
          description: editDraft.description.trim(),
        },
      });
      setEditingInModal(false);
      setNotice(
        `Updated business details for ${editDraft.businessName.trim()}.`,
      );
      await loadBusinesses();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "Failed to save business detail edits.",
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

  async function handleDeleteBusiness(biz: BusinessListingRecord) {
    if (
      !window.confirm(
        `Delete business listing "${biz.businessName}" (${biz.businessCode}) permanently?`,
      )
    ) {
      return;
    }
    setSubmitting(true);
    setError("");
    setNotice("");
    try {
      await adminApi(
        `/admin-review/businesses/${encodeURIComponent(biz.id)}`,
        {
          method: "DELETE",
        },
      );
      if (inspectingBiz?.id === biz.id) {
        setInspectingBiz(null);
      }
      setNotice(`Deleted business listing ${biz.businessName}.`);
      await loadBusinesses();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Failed to delete business listing.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleAddCategory() {
    const clean = newCategoryName.trim();
    if (clean.length < 2 || !data) return;
    if (
      data.categories.some((c) => c.toLowerCase() === clean.toLowerCase())
    ) {
      setError(`Category "${clean}" already exists.`);
      return;
    }
    const nextCategories = [...data.categories, clean];
    setSubmitting(true);
    setError("");
    try {
      await adminApi("/admin-review/platform-config", {
        method: "PUT",
        body: { businessCategories: nextCategories },
      });
      setNewCategoryName("");
      setNotice(`Added "${clean}" to Marketplace Business Categories.`);
      await loadBusinesses();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Could not update categories.",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleRemoveCategory(catToRemove: string) {
    if (!data || data.categories.length <= 1) return;
    const nextCategories = data.categories.filter((c) => c !== catToRemove);
    setSubmitting(true);
    setError("");
    try {
      await adminApi("/admin-review/platform-config", {
        method: "PUT",
        body: { businessCategories: nextCategories },
      });
      setNotice(`Removed "${catToRemove}" from Business Categories.`);
      await loadBusinesses();
    } catch (err) {
      setError(
        err instanceof Error ? err.message : "Could not remove category.",
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
    "Fashion and clothing",
    "Beauty and personal care",
    "Food and catering",
    "Health and fitness",
    "Education and training",
    "Home services",
    "Professional consulting",
    "Art and handicrafts",
    "Retail and ecommerce",
    "Events and photography",
    "Freelancers and independent professionals",
    "Other",
  ];
  const businesses = (data?.businesses ?? []).filter((b) => {
    if (statusFilter === "REPORTED" && !b.isReportedFraudulent) return false;
    if (
      statusFilter !== "ALL" &&
      statusFilter !== "REPORTED" &&
      b.approvalStatus !== statusFilter
    ) {
      return false;
    }
    if (searchFilter.trim()) {
      const q = searchFilter.trim().toLowerCase();
      return (
        b.businessName.toLowerCase().includes(q) ||
        b.businessCode.toLowerCase().includes(q) ||
        b.ownerDisplayName.toLowerCase().includes(q) ||
        b.category.toLowerCase().includes(q) ||
        b.city.toLowerCase().includes(q)
      );
    }
    return true;
  });

  const modalEnquiries = inspectingBiz
    ? (data?.enquiries ?? []).filter((e) => e.businessId === inspectingBiz.id)
    : [];
  const modalReports = inspectingBiz
    ? (data?.reports ?? []).filter((r) => r.businessId === inspectingBiz.id)
    : [];

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
            Review and approve women-owned business pages, inspect uploaded
            showcase photos, logos, operating hours, offerings catalogs, and
            customer enquiries, issue Verified Woman-Owned Business badges,
            curate featured placements, and govern marketplace categories.
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
            APPROVED &amp; PUBLIC LIVE
          </span>
          <div
            style={{
              fontSize: "28px",
              fontWeight: 800,
              color: "#1f6e4e",
              marginTop: "8px",
            }}
          >
            {metrics.approvedCount}{" "}
            <StatusPill tone="green">Public Marketplace</StatusPill>
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
          gridTemplateColumns: "1fr 1.55fr",
          gap: "22px",
          alignItems: "start",
        }}
      >
        {/* Left Column: Register Business + Category Governance */}
        <div style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
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
              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "1fr 1fr",
                  gap: "10px",
                }}
              >
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
                  Price Range
                  <input
                    value={priceRange}
                    onChange={(e) => setPriceRange(e.target.value)}
                    placeholder="₹500 – ₹2,500"
                    style={{
                      width: "100%",
                      marginTop: "4px",
                      padding: "10px 12px",
                      borderRadius: "10px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
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
                <Plus size={15} style={{ verticalAlign: "middle" }} /> Add
                Business to Queue
              </button>
            </div>
          </div>

          {/* Marketplace Category Governance */}
          <div
            style={{
              background: "#fff",
              borderRadius: "18px",
              border: "1px solid #eee7ee",
              padding: "22px",
            }}
          >
            <h3 style={{ margin: "0 0 10px 0", fontSize: "16px" }}>
              <Tag
                size={16}
                style={{ verticalAlign: "middle", marginRight: "6px" }}
              />
              Marketplace Category Governance ({categories.length})
            </h3>
            <div style={{ display: "flex", gap: "8px", marginBottom: "12px" }}>
              <input
                value={newCategoryName}
                onChange={(e) => setNewCategoryName(e.target.value)}
                placeholder="Add new business category..."
                style={{
                  flex: 1,
                  padding: "8px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                  fontSize: "13px",
                }}
              />
              <button
                type="button"
                className="secondary-button"
                disabled={submitting || newCategoryName.trim().length < 2}
                onClick={() => void handleAddCategory()}
              >
                <Plus size={14} /> Add
              </button>
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: "6px" }}>
              {categories.map((cat) => (
                <span
                  key={cat}
                  style={{
                    display: "inline-flex",
                    alignItems: "center",
                    gap: "6px",
                    padding: "4px 10px",
                    borderRadius: "999px",
                    background: "#f8f2fa",
                    border: "1px solid #e5d4ec",
                    fontSize: "12px",
                    fontWeight: 600,
                    color: "#52345f",
                  }}
                >
                  {cat}
                  {categories.length > 1 && (
                    <button
                      type="button"
                      title={`Remove ${cat}`}
                      onClick={() => void handleRemoveCategory(cat)}
                      style={{
                        border: 0,
                        background: "transparent",
                        color: "#a63b4a",
                        cursor: "pointer",
                        padding: 0,
                        fontWeight: 800,
                      }}
                    >
                      ×
                    </button>
                  )}
                </span>
              ))}
            </div>
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
            <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
              <input
                value={searchFilter}
                onChange={(e) => setSearchFilter(e.target.value)}
                placeholder="Search name, founder, city..."
                style={{
                  padding: "8px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                  fontSize: "13px",
                }}
              />
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
                <option value="REJECTED">Rejected</option>
                <option value="SUSPENDED">Suspended</option>
                <option value="REPORTED">Reported / Fraud Flagged</option>
              </select>
            </div>
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
                const galleryCount = Array.isArray(biz.mediaGallery)
                  ? biz.mediaGallery.length
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
                              : biz.approvalStatus === "SUSPENDED" ||
                                  biz.approvalStatus === "REJECTED"
                                ? "urgent"
                                : "amber"
                          }
                        >
                          {formatEnumLabel(biz.approvalStatus)}
                        </StatusPill>
                        <StatusPill
                          tone={
                            biz.verificationBadgeStatus ===
                            "VERIFIED_WOMAN_OWNED"
                              ? "rose"
                              : "neutral"
                          }
                        >
                          {formatEnumLabel(biz.verificationBadgeStatus)}
                        </StatusPill>
                        {biz.isFeatured && (
                          <StatusPill tone="green">Featured ★</StatusPill>
                        )}
                        {galleryCount > 0 && (
                          <StatusPill tone="neutral">
                            {galleryCount} Photos
                          </StatusPill>
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
                              style={{
                                verticalAlign: "middle",
                                marginRight: 3,
                              }}
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
                    {biz.reviewNotes && (
                      <div
                        style={{
                          marginBottom: "10px",
                          padding: "8px 12px",
                          borderRadius: "8px",
                          background: "#fff8e6",
                          color: "#92400e",
                          fontSize: "12px",
                          fontWeight: 600,
                        }}
                      >
                        Reviewer Notes: {biz.reviewNotes}
                      </div>
                    )}
                    <div
                      style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}
                    >
                      <button
                        type="button"
                        className="secondary-button"
                        onClick={() => {
                          setInspectingBiz(biz);
                          setReviewNotesDraft(biz.reviewNotes ?? "");
                          setEditingInModal(false);
                          setEditDraft({
                            businessName: biz.businessName,
                            category: biz.category,
                            city: biz.city,
                            serviceArea: biz.serviceArea ?? biz.city,
                            priceRange: biz.priceRange ?? "₹500 – ₹2,500",
                            contactPhone: biz.contactPhone ?? "",
                            whatsappNumber: biz.whatsappNumber ?? "",
                            websiteOrInstagram: biz.websiteOrInstagram ?? "",
                            description: biz.description,
                          });
                        }}
                      >
                        <Eye size={14} /> Inspect 360° &amp; Media
                      </button>
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
                      <button
                        type="button"
                        className="secondary-button"
                        disabled={submitting}
                        onClick={() => void handleDeleteBusiness(biz)}
                        style={{ color: "#991b1b" }}
                      >
                        <Trash2 size={14} /> Delete
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* 360° Business Inspection Modal */}
      {inspectingBiz && (
        <div
          style={{
            position: "fixed",
            inset: 0,
            background: "rgba(33, 18, 42, 0.55)",
            backdropFilter: "blur(6px)",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            zIndex: 9999,
            padding: "24px",
          }}
        >
          <div
            style={{
              background: "#fff",
              borderRadius: "22px",
              maxWidth: "840px",
              width: "100%",
              maxHeight: "90vh",
              overflowY: "auto",
              padding: "26px",
              boxShadow: "0 24px 60px rgba(33,18,42,0.28)",
            }}
          >
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "flex-start",
                gap: "12px",
                marginBottom: "16px",
              }}
            >
              <div>
                <div
                  style={{
                    display: "flex",
                    gap: "8px",
                    alignItems: "center",
                    marginBottom: "6px",
                  }}
                >
                  <StatusPill tone="rose">
                    360° BUSINESS DOSSIER • {inspectingBiz.businessCode}
                  </StatusPill>
                  <StatusPill
                    tone={
                      inspectingBiz.approvalStatus === "APPROVED"
                        ? "green"
                        : "amber"
                    }
                  >
                    {formatEnumLabel(inspectingBiz.approvalStatus)}
                  </StatusPill>
                </div>
                <h2 style={{ margin: 0, fontSize: "22px", color: "#31263a" }}>
                  {inspectingBiz.businessName}
                </h2>
                <p style={{ margin: "4px 0 0 0", color: "#6e6275" }}>
                  Founder: <strong>{inspectingBiz.ownerDisplayName}</strong> •{" "}
                  {inspectingBiz.category} • {inspectingBiz.city} (
                  {inspectingBiz.serviceArea || inspectingBiz.city})
                </p>
              </div>
              <div style={{ display: "flex", gap: "8px" }}>
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() => setEditingInModal((v) => !v)}
                >
                  <Edit3 size={14} />{" "}
                  {editingInModal ? "Cancel Edit" : "Edit Details"}
                </button>
                <button
                  type="button"
                  className="secondary-button"
                  onClick={() => setInspectingBiz(null)}
                >
                  Close ✕
                </button>
              </div>
            </div>

            {editingInModal && (
              <div
                style={{
                  padding: "16px",
                  borderRadius: "14px",
                  background: "#f8f2fa",
                  border: "1px solid #decbe6",
                  marginBottom: "16px",
                }}
              >
                <strong
                  style={{
                    display: "block",
                    marginBottom: "10px",
                    color: "#631d76",
                  }}
                >
                  Admin Quick-Edit Business Listing
                </strong>
                <div
                  style={{
                    display: "grid",
                    gridTemplateColumns: "1fr 1fr",
                    gap: "10px",
                    marginBottom: "10px",
                  }}
                >
                  <input
                    value={editDraft.businessName}
                    onChange={(e) =>
                      setEditDraft({
                        ...editDraft,
                        businessName: e.target.value,
                      })
                    }
                    placeholder="Business Name"
                    style={{
                      padding: "8px 10px",
                      borderRadius: "8px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                  <select
                    value={editDraft.category}
                    onChange={(e) =>
                      setEditDraft({ ...editDraft, category: e.target.value })
                    }
                    style={{
                      padding: "8px 10px",
                      borderRadius: "8px",
                      border: "1px solid #dcd0e0",
                    }}
                  >
                    {categories.map((c) => (
                      <option key={c} value={c}>
                        {c}
                      </option>
                    ))}
                  </select>
                  <input
                    value={editDraft.city}
                    onChange={(e) =>
                      setEditDraft({ ...editDraft, city: e.target.value })
                    }
                    placeholder="City"
                    style={{
                      padding: "8px 10px",
                      borderRadius: "8px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                  <input
                    value={editDraft.serviceArea}
                    onChange={(e) =>
                      setEditDraft({
                        ...editDraft,
                        serviceArea: e.target.value,
                      })
                    }
                    placeholder="Service Area"
                    style={{
                      padding: "8px 10px",
                      borderRadius: "8px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                  <input
                    value={editDraft.priceRange}
                    onChange={(e) =>
                      setEditDraft({ ...editDraft, priceRange: e.target.value })
                    }
                    placeholder="Price Range"
                    style={{
                      padding: "8px 10px",
                      borderRadius: "8px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                  <input
                    value={editDraft.contactPhone}
                    onChange={(e) =>
                      setEditDraft({
                        ...editDraft,
                        contactPhone: e.target.value,
                      })
                    }
                    placeholder="Contact Phone"
                    style={{
                      padding: "8px 10px",
                      borderRadius: "8px",
                      border: "1px solid #dcd0e0",
                    }}
                  />
                </div>
                <textarea
                  rows={2}
                  value={editDraft.description}
                  onChange={(e) =>
                    setEditDraft({ ...editDraft, description: e.target.value })
                  }
                  placeholder="Business Description"
                  style={{
                    width: "100%",
                    padding: "8px 10px",
                    borderRadius: "8px",
                    border: "1px solid #dcd0e0",
                    marginBottom: "10px",
                  }}
                />
                <button
                  type="button"
                  className="secondary-button"
                  disabled={submitting}
                  onClick={() => void handleSaveModalEdits()}
                  style={{
                    background: "#631d76",
                    color: "#fff",
                    borderColor: "#631d76",
                  }}
                >
                  Save Listing Edits
                </button>
              </div>
            )}

            <div
              style={{
                display: "grid",
                gridTemplateColumns: "1fr 1fr",
                gap: "14px",
                marginBottom: "16px",
              }}
            >
              <div
                style={{
                  padding: "14px",
                  background: "#fdf9fc",
                  borderRadius: "14px",
                  border: "1px solid #eee7ee",
                }}
              >
                <strong style={{ fontSize: "12.5px", color: "#631d76" }}>
                  <Phone
                    size={13}
                    style={{ verticalAlign: "middle", marginRight: 4 }}
                  />
                  Contact &amp; Privacy Channels
                </strong>
                <div
                  style={{
                    fontSize: "13px",
                    marginTop: "6px",
                    lineHeight: 1.5,
                  }}
                >
                  <div>
                    Phone: {inspectingBiz.contactPhone || "Not provided"}{" "}
                    {inspectingBiz.hidePhoneNumber
                      ? "(Masked on Public Page)"
                      : "(Public)"}
                  </div>
                  <div>
                    WhatsApp:{" "}
                    {inspectingBiz.whatsappNumber ||
                      inspectingBiz.contactPhone ||
                      "Not provided"}
                  </div>
                  <div>
                    Instagram / Web:{" "}
                    {inspectingBiz.websiteOrInstagram ||
                      inspectingBiz.instagramHandle ||
                      "Not provided"}
                  </div>
                  <div>
                    Price Range: {inspectingBiz.priceRange || "Not specified"}
                  </div>
                </div>
              </div>

              <div
                style={{
                  padding: "14px",
                  background: "#fdf9fc",
                  borderRadius: "14px",
                  border: "1px solid #eee7ee",
                }}
              >
                <strong style={{ fontSize: "12.5px", color: "#631d76" }}>
                  <Clock
                    size={13}
                    style={{ verticalAlign: "middle", marginRight: 4 }}
                  />
                  Operating Hours &amp; Engagement
                </strong>
                <div
                  style={{
                    fontSize: "13px",
                    marginTop: "6px",
                    lineHeight: 1.5,
                  }}
                >
                  <div>
                    Mon–Fri:{" "}
                    {String(
                      (inspectingBiz.businessHours as Record<string, unknown>)
                        ?.mondayToFriday ?? "10:00 AM – 7:00 PM",
                    )}
                  </div>
                  <div>
                    Saturday:{" "}
                    {String(
                      (inspectingBiz.businessHours as Record<string, unknown>)
                        ?.saturday ?? "10:00 AM – 5:00 PM",
                    )}
                  </div>
                  <div>
                    Sunday:{" "}
                    {String(
                      (inspectingBiz.businessHours as Record<string, unknown>)
                        ?.sunday ?? "By Appointment",
                    )}
                  </div>
                  <div>
                    Enquiries: {inspectingBiz.enquiriesCount ?? 0} • Views:{" "}
                    {inspectingBiz.viewsCount ?? 0}
                  </div>
                </div>
              </div>
            </div>

            {/* Visual Media Gallery & Branding Preview */}
            <div style={{ marginBottom: "16px" }}>
              <strong
                style={{
                  display: "block",
                  fontSize: "13px",
                  marginBottom: "8px",
                }}
              >
                <ImageIcon
                  size={14}
                  style={{ verticalAlign: "middle", marginRight: 5 }}
                />
                Uploaded Brand Assets &amp; Showcase Photos (
                {Array.isArray(inspectingBiz.mediaGallery)
                  ? inspectingBiz.mediaGallery.length
                  : 0}{" "}
                / 3)
              </strong>
              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "repeat(auto-fill, minmax(150px, 1fr))",
                  gap: "10px",
                }}
              >
                {[
                  ...(inspectingBiz.logoAsset
                    ? [{ label: "Brand Logo", url: inspectingBiz.logoAsset }]
                    : []),
                  ...(inspectingBiz.coverImage
                    ? [{ label: "Cover Banner", url: inspectingBiz.coverImage }]
                    : []),
                  ...(Array.isArray(inspectingBiz.mediaGallery)
                    ? inspectingBiz.mediaGallery.map((u, idx) => ({
                        label: `Showcase #${idx + 1}`,
                        url: String(u),
                      }))
                    : []),
                ].map((asset, idx) => {
                  const resolved = resolveMediaPreviewUrl(asset.url);
                  return (
                    <div
                      key={idx}
                      style={{
                        borderRadius: "12px",
                        border: "1px solid #e6d9eb",
                        padding: "8px",
                        background: "#fdf9fc",
                      }}
                    >
                      {resolved ? (
                        <a
                          href={resolved}
                          target="_blank"
                          rel="noreferrer"
                          style={{ display: "block" }}
                        >
                          <img
                            src={resolved}
                            alt={asset.label}
                            style={{
                              width: "100%",
                              height: "96px",
                              objectFit: "cover",
                              borderRadius: "8px",
                              background: "#f3eaf7",
                            }}
                          />
                        </a>
                      ) : (
                        <div
                          style={{
                            width: "100%",
                            height: "96px",
                            borderRadius: "8px",
                            background:
                              "linear-gradient(135deg, #f3e8ff, #fce7f3)",
                            display: "flex",
                            alignItems: "center",
                            justifyContent: "center",
                            fontSize: "11px",
                            fontWeight: 700,
                            color: "#631d76",
                            textAlign: "center",
                            padding: "6px",
                          }}
                        >
                          App Studio Asset
                          <br />
                          {asset.url.split("/").pop()}
                        </div>
                      )}
                      <div
                        style={{
                          fontSize: "11.5px",
                          fontWeight: 700,
                          marginTop: "6px",
                          color: "#31263a",
                        }}
                      >
                        {asset.label}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {Array.isArray(inspectingBiz.productsServices) &&
              inspectingBiz.productsServices.length > 0 && (
                <div style={{ marginBottom: "16px" }}>
                  <strong
                    style={{
                      display: "block",
                      fontSize: "13px",
                      marginBottom: "8px",
                    }}
                  >
                    Products &amp; Services Catalog (
                    {inspectingBiz.productsServices.length})
                  </strong>
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns:
                        "repeat(auto-fit, minmax(220px, 1fr))",
                      gap: "10px",
                    }}
                  >
                    {inspectingBiz.productsServices.map((item, idx) => (
                      <div
                        key={idx}
                        style={{
                          padding: "10px 12px",
                          borderRadius: "10px",
                          border: "1px solid #e6d9eb",
                          background: "#fff",
                        }}
                      >
                        <div
                          style={{
                            fontWeight: 700,
                            fontSize: "13px",
                            color: "#31263a",
                          }}
                        >
                          {String(item.title ?? item.name ?? "Offering")} •{" "}
                          <span style={{ color: "#b45309" }}>
                            {String(item.price ?? "On Request")}
                          </span>
                        </div>
                        {Boolean(item.description) && (
                          <div
                            style={{
                              fontSize: "12px",
                              color: "#6e6275",
                              marginTop: "2px",
                            }}
                          >
                            {String(item.description ?? "")}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

            {Array.isArray(inspectingBiz.offersAndPosts) &&
              inspectingBiz.offersAndPosts.length > 0 && (
                <div style={{ marginBottom: "16px" }}>
                  <strong
                    style={{
                      display: "block",
                      fontSize: "13px",
                      marginBottom: "8px",
                    }}
                  >
                    Promotional Offers &amp; Updates (
                    {inspectingBiz.offersAndPosts.length})
                  </strong>
                  <div
                    style={{
                      display: "grid",
                      gridTemplateColumns:
                        "repeat(auto-fit, minmax(220px, 1fr))",
                      gap: "10px",
                    }}
                  >
                    {inspectingBiz.offersAndPosts.map((offer, idx) => (
                      <div
                        key={idx}
                        style={{
                          padding: "10px 12px",
                          borderRadius: "10px",
                          border: "1px solid #f5d0fe",
                          background: "#fdf4ff",
                        }}
                      >
                        <div style={{ fontWeight: 700, fontSize: "13px" }}>
                          {String(offer.title ?? "Special Offer")}{" "}
                          {offer.badge ? `• ${String(offer.badge)}` : ""}
                        </div>
                        {Boolean(offer.description) && (
                          <div style={{ fontSize: "12px", color: "#6e6275" }}>
                            {String(offer.description ?? "")}
                          </div>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

            {modalEnquiries.length > 0 && (
              <div style={{ marginBottom: "16px" }}>
                <strong
                  style={{
                    display: "block",
                    fontSize: "13px",
                    marginBottom: "8px",
                  }}
                >
                  Customer Enquiries Log ({modalEnquiries.length})
                </strong>
                <div
                  style={{
                    display: "flex",
                    flexDirection: "column",
                    gap: "8px",
                  }}
                >
                  {modalEnquiries.map((enq) => (
                    <div
                      key={enq.id}
                      style={{
                        padding: "10px 12px",
                        borderRadius: "10px",
                        background: "#f8fafc",
                        border: "1px solid #e2e8f0",
                        fontSize: "12.5px",
                      }}
                    >
                      <strong>
                        {enq.senderDisplayName || "Sakhi Member"}{" "}
                        {enq.senderUsername ? `(${enq.senderUsername})` : ""}
                      </strong>{" "}
                      • {enq.subjectOrProduct || "Enquiry"} •{" "}
                      <StatusPill tone="neutral">
                        {enq.status || "OPEN"}
                      </StatusPill>
                    </div>
                  ))}
                </div>
              </div>
            )}

            {modalReports.length > 0 && (
              <div style={{ marginBottom: "16px" }}>
                <strong
                  style={{
                    display: "block",
                    fontSize: "13px",
                    marginBottom: "8px",
                    color: "#a63b4a",
                  }}
                >
                  Member Safety Reports ({modalReports.length})
                </strong>
                {modalReports.map((rep) => (
                  <div
                    key={rep.id}
                    style={{
                      padding: "10px 12px",
                      borderRadius: "10px",
                      background: "#fcebed",
                      color: "#a63b4a",
                      fontSize: "12.5px",
                      marginBottom: "6px",
                    }}
                  >
                    <strong>{rep.reason}</strong>
                    {rep.details ? ` — ${rep.details}` : ""}
                  </div>
                ))}
              </div>
            )}

            <label
              style={{
                display: "block",
                fontSize: "12.5px",
                fontWeight: 700,
                marginBottom: "14px",
              }}
            >
              Reviewer Decision Notes (shared directly with business owner in My
              Business Pages)
              <textarea
                rows={2}
                value={reviewNotesDraft}
                onChange={(e) => setReviewNotesDraft(e.target.value)}
                placeholder="Add approval notes or requested revisions..."
                style={{
                  width: "100%",
                  marginTop: "6px",
                  padding: "10px 12px",
                  borderRadius: "10px",
                  border: "1px solid #dcd0e0",
                }}
              />
            </label>

            <div style={{ display: "flex", gap: "10px", flexWrap: "wrap" }}>
              <button
                type="button"
                className="secondary-button"
                disabled={submitting}
                onClick={() =>
                  void handleReviewAction(
                    inspectingBiz,
                    {
                      approvalStatus: "APPROVED",
                      verificationBadgeStatus: "VERIFIED_WOMAN_OWNED",
                      reviewNotes:
                        reviewNotesDraft.trim() ||
                        "Approved & Verified Woman-Owned by Sakhi Role 5 Admin.",
                    },
                    "Approved & Verified listing",
                  )
                }
                style={{
                  background: "#1f6e4e",
                  color: "#fff",
                  borderColor: "#1f6e4e",
                }}
              >
                <CheckCircle2 size={14} /> Approve &amp; Grant Woman-Owned Badge
              </button>
              <button
                type="button"
                className="secondary-button"
                disabled={submitting}
                onClick={() =>
                  void handleReviewAction(
                    inspectingBiz,
                    {
                      approvalStatus: "REJECTED",
                      reviewNotes:
                        reviewNotesDraft.trim() ||
                        "Please add clearer product details and verify contact information.",
                    },
                    "Rejected listing with reviewer notes",
                  )
                }
                style={{ color: "#b4233c" }}
              >
                <XCircle size={14} /> Request Changes / Reject
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
