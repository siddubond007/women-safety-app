import { useCallback, useEffect, useState } from "react";
import {
  CheckCircle2,
  FolderKanban,
  Plus,
  RefreshCw,
  Trash2,
  UserCheck,
} from "lucide-react";
import { StatusPill } from "../components/StatusPill";
import { adminApi } from "../services/api/adminApi";

interface CategoryConfig {
  slug: string;
  name: string;
  description: string;
  iconKey: string;
  accentColorHex: string;
  isEnabled: boolean;
  displayOrder: number;
}

interface CommunityPostRow {
  id: string;
  authorAccountId?: string | null;
  authorName: string;
  authorUsername: string;
  content: string;
  categoryBadge: string | null;
  categorySlug?: string;
  visibility?: string;
  status?: string;
  feedSection: string;
  likesCount: number;
  commentsCount: number;
  createdAt: string;
}

interface MemberPublisherAccount {
  accountId: string;
  displayName: string;
  username: string;
  avatarAsset: string;
  verificationStatus: string;
  accountStatus: string;
  phoneE164: string;
}

interface MediaAssetRow {
  id: string;
  purpose: string;
  storageProvider: string;
  status: string;
  driveFileId: string | null;
  driveFolderPath: string;
  originalFileName: string;
  cropAspectRatio: string;
  byteSize: number;
  createdAt: string;
}

interface CommunityOverviewResponse {
  categories: CategoryConfig[];
  posts: CommunityPostRow[];
  memberAccounts?: MemberPublisherAccount[];
  mediaAssets?: MediaAssetRow[];
}

export function CommunityManagementPage() {
  const [data, setData] = useState<CommunityOverviewResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState("");
  const [error, setError] = useState("");
  const [newContent, setNewContent] = useState("");
  const [newBadge, setNewBadge] = useState("Safety Awareness");
  const [selectedPublisherAccountId, setSelectedPublisherAccountId] =
    useState<string>(() => {
      try {
        return (
          window.localStorage.getItem("sakhi_admin_publisher_account_id") || ""
        );
      } catch {
        return "";
      }
    });

  const fetchOverview = useCallback(
    () => adminApi<CommunityOverviewResponse>("/admin-review/community"),
    [],
  );

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const res = await fetchOverview();
      setData(res);
      if (
        !selectedPublisherAccountId &&
        res.memberAccounts &&
        res.memberAccounts.length > 0
      ) {
        const firstVerified =
          res.memberAccounts.find(
            (m) => m.verificationStatus === "VERIFIED",
          ) ?? res.memberAccounts[0]!;
        setSelectedPublisherAccountId(firstVerified.accountId);
      }
    } catch (e) {
      setError(
        e instanceof Error ? e.message : "Could not load community overview.",
      );
    } finally {
      setLoading(false);
    }
  }, [fetchOverview, selectedPublisherAccountId]);

  useEffect(() => {
    let active = true;

    fetchOverview()
      .then((res) => {
        if (active) {
          setData(res);
          if (
            !selectedPublisherAccountId &&
            res.memberAccounts &&
            res.memberAccounts.length > 0
          ) {
            const firstVerified =
              res.memberAccounts.find(
                (m) => m.verificationStatus === "VERIFIED",
              ) ?? res.memberAccounts[0]!;
            setSelectedPublisherAccountId(firstVerified.accountId);
          }
          setError("");
        }
      })
      .catch((e: unknown) => {
        if (active) {
          setError(
            e instanceof Error
              ? e.message
              : "Could not load community overview.",
          );
        }
      })
      .finally(() => {
        if (active) setLoading(false);
      });

    return () => {
      active = false;
    };
  }, [fetchOverview, selectedPublisherAccountId]);

  function handleSelectPublisher(accountId: string) {
    setSelectedPublisherAccountId(accountId);
    try {
      window.localStorage.setItem(
        "sakhi_admin_publisher_account_id",
        accountId,
      );
    } catch {
      // Ignore storage errors
    }
  }

  async function toggleCategory(cat: CategoryConfig) {
    try {
      await adminApi(`/admin-review/categories/${cat.slug}`, {
        method: "PUT",
        body: {
          name: cat.name,
          description: cat.description,
          isEnabled: !cat.isEnabled,
          displayOrder: cat.displayOrder,
        },
      });
      setNotice(
        `Updated category "${cat.name}" (${!cat.isEnabled ? "Enabled" : "Disabled"}).`,
      );
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to update category.");
    }
  }

  async function publishSpotlightPost() {
    if (!newContent.trim()) return;
    const chosenMember = (data?.memberAccounts ?? []).find(
      (m) => m.accountId === selectedPublisherAccountId,
    );
    try {
      await adminApi("/admin-review/community/posts", {
        method: "POST",
        body: {
          content: newContent.trim(),
          categoryBadge: newBadge,
          feedSection: "community",
          ...(chosenMember
            ? {
                authorAccountId: chosenMember.accountId,
                authorName: chosenMember.displayName,
                authorUsername: chosenMember.username,
                authorAvatar: chosenMember.avatarAsset,
              }
            : {}),
        },
      });
      setNewContent("");
      setNotice(
        chosenMember
          ? `Published official community post as ${chosenMember.displayName} (${chosenMember.username}) with 0 initial reactions.`
          : "Published official community post to the Sakhi Social Wall.",
      );
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not publish post.");
    }
  }

  async function moderatePost(
    postId: string,
    actionType: "REMOVE_POST" | "RESTORE_CONTENT",
  ) {
    try {
      await adminApi(`/admin-review/moderation/posts/${postId}/action`, {
        method: "POST",
        body: {
          actionType,
          reason:
            actionType === "REMOVE_POST"
              ? "Removed by Super Admin via Community Governance."
              : "Restored by Super Admin.",
        },
      });
      setNotice(`Post ${postId.slice(0, 8)} updated (${actionType}).`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Moderation update failed.");
    }
  }

  const publisherAccounts = data?.memberAccounts ?? [];
  const activePublisher = publisherAccounts.find(
    (m) => m.accountId === selectedPublisherAccountId,
  );

  return (
    <div className="dashboard-page">
      <section className="page-heading">
        <div>
          <div className="eyebrow">
            <span className="eyebrow-line" /> MODULE 3 SOCIAL WALL GOVERNANCE
          </div>
          <h1>Community &amp; Feed Categories</h1>
          <p>
            Manage the 6 SRS 5.3 Social Wall categories, link an official
            registered Sakhi user account for Admin announcements, moderate
            member posts, and inspect private Google Drive media paths.
          </p>
        </div>
        <div className="heading-meta">
          <StatusPill tone="green">6 CATEGORIES ACTIVE</StatusPill>
          <button
            className="button button--secondary"
            type="button"
            onClick={() => void load()}
            disabled={loading}
          >
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </section>

      {notice && (
        <div
          className="member-toast"
          role="status"
          style={{ marginBottom: 16 }}
        >
          <CheckCircle2 size={17} />
          <span>{notice}</span>
        </div>
      )}
      {error && (
        <div
          className="panel"
          role="alert"
          style={{ padding: 16, marginBottom: 16 }}
        >
          <strong>Error:</strong> {error}
        </div>
      )}

      {data && (
        <>
          {/* Official Admin Publisher Account Selector & Post Composer (Flaw 21 Fix) */}
          <section className="panel queue-panel" style={{ marginBottom: 20 }}>
            <div className="panel-heading">
              <div>
                <span className="panel-kicker">
                  LINKED SAKHI USER ACCOUNT PUBLISHER
                </span>
                <h2>Publish Official Post from a Registered Sakhi Account</h2>
                <p>
                  Select any real registered Sakhi member account below to act
                  as the official publisher for admin announcements and safety
                  advisories. Posts start with real live engagement counts (0
                  reactions, 0 comments).
                </p>
              </div>
              <UserCheck size={20} color="#5A1868" />
            </div>

            <div
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fit, minmax(220px, 1fr))",
                gap: 12,
                padding: "12px 0",
                alignItems: "end",
              }}
            >
              <label className="member-filter-select">
                <span>Publish As (Registered Sakhi User Account)</span>
                <select
                  value={selectedPublisherAccountId}
                  onChange={(e) => handleSelectPublisher(e.target.value)}
                >
                  {publisherAccounts.length === 0 && (
                    <option value="">Default Verified Sakhi Account</option>
                  )}
                  {publisherAccounts.map((acc) => (
                    <option key={acc.accountId} value={acc.accountId}>
                      {acc.displayName} ({acc.username}) ·{" "}
                      {acc.verificationStatus}
                    </option>
                  ))}
                </select>
              </label>

              <label className="member-filter-select">
                <span>Feed Category Badge</span>
                <select
                  value={newBadge}
                  onChange={(e) => setNewBadge(e.target.value)}
                >
                  <option value="Safety Awareness">Safety Awareness</option>
                  <option value="Community">Community</option>
                  <option value="Trending">Trending</option>
                  <option value="Business Updates">Business Updates</option>
                  <option value="Wellness and Lifestyle">
                    Wellness and Lifestyle
                  </option>
                </select>
              </label>
            </div>

            {activePublisher && (
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                  padding: "10px 14px",
                  borderRadius: 12,
                  background: "#faf5fb",
                  border: "1px solid #ead8e8",
                  marginBottom: 12,
                  fontSize: 13,
                }}
              >
                <UserCheck size={16} color="#5A1868" />
                <span>
                  Active Admin Publisher:{" "}
                  <strong>{activePublisher.displayName}</strong> (
                  <code>{activePublisher.username}</code>) — tapping this post’s
                  author in the mobile app opens their real Sakhi profile.
                </span>
              </div>
            )}

            <div
              style={{
                display: "flex",
                gap: 12,
                padding: "4px 0 8px",
                flexWrap: "wrap",
              }}
            >
              <input
                style={{
                  flex: "1 1 340px",
                  padding: "11px 14px",
                  borderRadius: 11,
                  border: "1px solid #dccad9",
                  fontSize: 13.5,
                }}
                placeholder="Write a verified community update, safety advisory, or announcement..."
                value={newContent}
                onChange={(e) => setNewContent(e.target.value)}
              />
              <button
                className="primary-button"
                type="button"
                onClick={() => void publishSpotlightPost()}
              >
                <Plus size={15} /> Publish Post as{" "}
                {activePublisher ? activePublisher.displayName : "Selected User"}
              </button>
            </div>
          </section>

          <section className="panel queue-panel" style={{ marginBottom: 20 }}>
            <div className="panel-heading">
              <div>
                <span className="panel-kicker">SRS SECTION 5.3</span>
                <h2>Social Wall Feed Categories (6)</h2>
                <p>
                  Toggle category availability or inspect display order across
                  the Flutter mobile app.
                </p>
              </div>
            </div>
            <div className="table-scroll">
              <table className="operations-table">
                <thead>
                  <tr>
                    <th>Order</th>
                    <th>Category</th>
                    <th>Slug</th>
                    <th>Description</th>
                    <th>Status</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {data.categories.map((cat) => (
                    <tr key={cat.slug}>
                      <td>#{cat.displayOrder}</td>
                      <td>
                        <strong>{cat.name}</strong>
                      </td>
                      <td>
                        <code>{cat.slug}</code>
                      </td>
                      <td>{cat.description}</td>
                      <td>
                        <StatusPill tone={cat.isEnabled ? "green" : "amber"}>
                          {cat.isEnabled ? "Enabled" : "Disabled"}
                        </StatusPill>
                      </td>
                      <td>
                        <button
                          className="secondary-button"
                          type="button"
                          onClick={() => void toggleCategory(cat)}
                        >
                          {cat.isEnabled ? "Disable" : "Enable"}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className="panel queue-panel" style={{ marginBottom: 20 }}>
            <div className="panel-heading">
              <div>
                <span className="panel-kicker">
                  LIVE SOCIAL WALL POSTS ({data.posts.length})
                </span>
                <h2>Member &amp; Spotlight Posts</h2>
              </div>
            </div>
            <div className="table-scroll">
              <table className="operations-table">
                <thead>
                  <tr>
                    <th>Author</th>
                    <th>Category</th>
                    <th>Content</th>
                    <th>Live Engagement</th>
                    <th>Status</th>
                    <th>Moderation</th>
                  </tr>
                </thead>
                <tbody>
                  {data.posts.map((post) => (
                    <tr key={post.id}>
                      <td>
                        <strong>{post.authorName}</strong>
                        <div style={{ fontSize: 12, opacity: 0.75 }}>
                          {post.authorUsername}
                        </div>
                      </td>
                      <td>
                        {post.categoryBadge || post.categorySlug || "Community"}
                      </td>
                      <td style={{ maxWidth: 420 }}>{post.content}</td>
                      <td>
                        {post.likesCount} reactions · {post.commentsCount}{" "}
                        comments
                      </td>
                      <td>
                        <StatusPill
                          tone={
                            post.status === "REMOVED_BY_MODERATOR"
                              ? "rose"
                              : "green"
                          }
                        >
                          {(post.status || "PUBLISHED").replace(/_/g, " ")}
                        </StatusPill>
                      </td>
                      <td>
                        {post.status === "REMOVED_BY_MODERATOR" ? (
                          <button
                            className="secondary-button"
                            type="button"
                            onClick={() =>
                              void moderatePost(post.id, "RESTORE_CONTENT")
                            }
                          >
                            Restore
                          </button>
                        ) : (
                          <button
                            className="secondary-button"
                            type="button"
                            onClick={() =>
                              void moderatePost(post.id, "REMOVE_POST")
                            }
                          >
                            <Trash2 size={13} /> Remove
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>

          <section className="panel queue-panel">
            <div className="panel-heading">
              <div>
                <span className="panel-kicker">
                  PRIVATE GOOGLE DRIVE HIERARCHY
                </span>
                <h2>Persisted Media Assets ({data.mediaAssets?.length ?? 0})</h2>
                <p>
                  All uploaded profile photos and post attachments are organized
                  under{" "}
                  <code>Sakhi Media/users/&#123;opaqueUserId&#125;/profile</code>{" "}
                  and{" "}
                  <code>
                    Sakhi Media/feeds/&#123;categorySlug&#125;/&#123;opaqueUserId&#125;/&#123;postId&#125;
                  </code>
                  .
                </p>
              </div>
              <FolderKanban size={20} />
            </div>
            <div className="table-scroll">
              <table className="operations-table">
                <thead>
                  <tr>
                    <th>Purpose</th>
                    <th>Drive Folder Path</th>
                    <th>File Name</th>
                    <th>Crop</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {(data.mediaAssets ?? []).length === 0 && (
                    <tr>
                      <td colSpan={5} className="member-empty-cell">
                        No Google Drive MediaAsset rows recorded yet. Upload a
                        profile photo or post image in the mobile app.
                      </td>
                    </tr>
                  )}
                  {(data.mediaAssets ?? []).map((asset) => (
                    <tr key={asset.id}>
                      <td>{asset.purpose.replace(/_/g, " ")}</td>
                      <td>
                        <code>{asset.driveFolderPath}</code>
                      </td>
                      <td>{asset.originalFileName}</td>
                      <td>{asset.cropAspectRatio}</td>
                      <td>
                        <StatusPill tone="green">{asset.status}</StatusPill>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
