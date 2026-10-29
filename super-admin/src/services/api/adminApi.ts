import { adminAuthService, isStagingTestAdminMode } from "../auth/adminAuthService";

export const API_BASE_URL = (
  // Safe hosted fallback: no client should call its own localhost when a deploy variable is missing.
  import.meta.env.VITE_API_BASE_URL ?? "https://sakhi-staging-api.onrender.com/api/v1"
).replace(/\/+$/, "");

export class AdminApiError extends Error {
  constructor(message: string, readonly statusCode: number) {
    super(message);
    this.name = "AdminApiError";
  }
}

export async function adminApi<T>(
  path: string,
  options: { method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE"; body?: unknown } = {},
): Promise<T> {
  const token = adminAuthService.getToken();
  const headers: Record<string, string> = { Accept: "application/json" };
  if (isStagingTestAdminMode && token) {
    headers["X-Sakhi-Staging-Admin-Session"] = token;
  } else if (!isStagingTestAdminMode && token) {
    headers["X-Sakhi-Admin-Token"] = token;
    headers["x-sakhi-admin-review-token"] = token;
  }
  if (options.body !== undefined) headers["Content-Type"] = "application/json";
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method ?? "GET",
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
    credentials: "omit",
    cache: "no-store",
  });
  const data = (await response.json().catch(() => ({}))) as { message?: string | string[] };
  if (!response.ok) {
    const message = Array.isArray(data.message) ? data.message.join(" ") : data.message;
    throw new AdminApiError(
      message || `Admin API request failed (${response.status}).`,
      response.status,
    );
  }
  return data as T;
}
