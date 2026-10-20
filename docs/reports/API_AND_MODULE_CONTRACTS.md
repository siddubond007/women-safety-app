# Sakhi Module 2, Module 3 & Super Admin — API and Cross-Module Contracts

## 1. Base URLs & Local Port Allocation
- **NestJS Backend API**: `http://127.0.0.1:3001/api/v1`
- **Super Admin Portal (Vite)**: `http://127.0.0.1:5173` (configured via `VITE_API_BASE_URL=http://127.0.0.1:3001/api/v1`)
- **Flutter Android Debug APK (USB `adb reverse tcp:3001 tcp:3001`)**: `http://127.0.0.1:3001/api/v1`

## 2. Member Social Wall & Media Endpoints (`/api/v1/module2/*`)
All member mutations and protected reads require `Authorization: Bearer <accessToken>` belonging to an `ACTIVE` account with `eligibilityStatus = VERIFIED`.

| Method & Path | Purpose | Request Body / Params | Response Contract |
| :--- | :--- | :--- | :--- |
| `GET /module2/bootstrap` | Loads current user profile, 6 feed categories, visible feed posts, groups, followers/following, wellness logs, safety contacts, and notifications | Header: `Authorization: Bearer <token>` | `{ currentUser, categories, posts, groups, followers, following, discoverMembers, blockedUsers, wellness, safety, notifications }` |
| `GET /module2/categories` | Lists enabled SRS 5.3 feed categories in display order | None | `{ categories: FeedCategoryConfig[] }` |
| `GET /module2/posts` | Lists feed posts filtered by category, topic, search query, or saved-only, excluding blocked users and enforcing `VERIFIED_MEMBERS` / `FOLLOWERS_ONLY` / `PRIVATE_SELF` visibility | Query: `categorySlug`, `topic`, `search`, `savedOnly`, `limit` | `{ items: Post[], posts: Post[], total: number }` |
| `POST /module2/posts` | Creates a new Social Wall post and attaches uploaded `MediaAsset` IDs (relocating staged Google Drive files to `Sakhi Media/feeds/{categorySlug}/{userId}/{postId}`) | `{ body, categorySlug, visibility, cropPreset, hashtags, locationTag, allowComments, shareToBusinessProfile, mediaAsset, mediaUploadIds }` | `{ id, post, ... }` |
| `PATCH /module2/posts/:postId` | Owner-only post edit | `{ body, categorySlug, visibility, hashtags, locationTag, allowComments, cropPreset }` | `{ id, post, status: "EDITED" }` |
| `DELETE /module2/posts/:postId` | Owner-only post deletion (`403 post_delete_forbidden` if non-owner) | None | `{ deleted: true, postId }` |
| `POST /module2/posts/:postId/react` | Toggles or updates a member's reaction (`LIKE`, `LOVE`, `SUPPORT`, `INSPIRED`, `HAPPY`, `GRATEFUL`, `STRONG`, `CARE`) | `{ reactionType }` | `{ postId, isLiked, viewerReaction, likesCount, reactionsCount, reactionBreakdown }` |
| `POST /module2/posts/:postId/like` | Toggles standard heart like | None | `{ postId, isLiked, likesCount, reactionsCount }` |
| `POST /module2/posts/:postId/save` | Toggles post bookmark save | None | `{ postId, isSaved, savesCount }` |
| `GET /module2/posts/:postId/comments` | Lists active comments on a post | None | `{ items: Comment[], comments: Comment[] }` |
| `POST /module2/posts/:postId/comments` | Adds a comment (enforces `post.allowComments`) | `{ body }` | `{ comment }` |
| `PATCH /module2/posts/:postId/comments/:commentId` | Comment-owner-only edit | `{ body }` | `{ comment }` |
| `DELETE /module2/posts/:postId/comments/:commentId` | Comment author OR post owner deletion (`403 comment_delete_forbidden` otherwise) | None | `{ deleted: true, commentId, postId }` |
| `POST /module2/media/upload` | Multipart binary upload (`file`, `purpose`, `categorySlug`, `cropAspectRatio`) to private Google Drive hierarchy | `multipart/form-data` | `{ uploadId, mediaId, purpose, driveFileId, driveFolderId, driveFolderPath, mediaUrl, cropAspectRatio }` |
| `GET /module2/media/object/:uploadId` | Streams binary media from Google Drive after verifying visibility, block rules, and moderation status | Header: `Authorization` (optional for public profile avatar, required for protected post scopes) | Binary image/video stream (`Cache-Control: private, max-age=300`) |
| `POST /module2/reports` | Submits confidential post, comment, or member report (`reporterAccountId` is never returned) | `{ targetType, postId, commentId, reportedAccountId, category, reason, details }` | `{ reportId, status, submittedAt, confidentialNotice }` |
| `POST /module2/members/:targetAccountId/block` | Blocks a member and removes mutual follow links in a transaction | `{ reason }` | `{ blockedAccountId, status: "BLOCKED" }` |

## 3. Super Admin Endpoints (`/api/v1/admin-review/*` & `/api/v1/integrations/*`)
All `/admin-review/*` endpoints require header `x-sakhi-admin-review-token` matching a token configured in `SAKHI_ADMIN_REVIEW_TOKEN` (verified via `timingSafeEqual`).

- `GET /api/v1/admin-review/queue?status=actionable|all` — Lists eligibility review queue.
- `POST /api/v1/admin-review/accounts/:accountId/decision` — Records `APPROVE_VERIFIED`, `REJECT`, `TEMPORARILY_RESTRICT`, or `REQUIRE_REVERIFICATION`.
- `GET /api/v1/admin-review/operations` — Returns live counts, `categories`, `posts`, `reports`, `moderationDecisions`, `mediaAssets`, `safetyEvents`, `auditTrail`, and `googleDriveStatus`.
- `PUT /api/v1/admin-review/categories/:slug` — Enables/disables, reorders, or updates any of the 6 SRS 5.3 feed categories.
- `POST /api/v1/admin-review/reports/:reportId/resolve` — Resolves a report with `DISMISS_REPORT`, `REMOVE_POST`, `REMOVE_COMMENT`, `WARN_MEMBER`, `RESTRICT_ACCOUNT`, or `SUSPEND_ACCOUNT`.
- `POST /api/v1/admin-review/posts/:postId/moderate` — Directly removes (`REMOVE_POST`) or restores (`RESTORE_CONTENT`) a post and updates associated `MediaAsset` status.
- `POST /api/v1/admin-review/comments/:commentId/moderate` — Directly removes (`REMOVE_COMMENT`) or restores (`RESTORE_CONTENT`) a comment.
- `GET /api/v1/integrations/google-drive/status?verify=true|false` — Verifies Google Drive OAuth token refresh and private root folder `Sakhi Media`.
