import { AsyncLocalStorage } from "node:async_hooks";

export interface DatabaseRequestIdentity {
  accountId?: string;
  sessionId?: string;
  adminStaffId?: string;
  adminRole?: string;
  authLookup?: boolean;
  usernameLookup?: boolean;
}

export const databaseRequestIdentityStorage =
  new AsyncLocalStorage<DatabaseRequestIdentity>();

export const databaseTransactionStorage = new AsyncLocalStorage<unknown>();

export function runWithDatabaseRequestIdentity<T>(
  operation: () => T,
  initialIdentity: Partial<DatabaseRequestIdentity> = {},
): T {
  return databaseRequestIdentityStorage.run({ ...initialIdentity }, operation);
}

export function setMemberDatabaseIdentity(accountId: string, sessionId: string): void {
  const identity = databaseRequestIdentityStorage.getStore();
  if (!identity) return;
  identity.accountId = accountId;
  identity.sessionId = sessionId;
  identity.adminStaffId = undefined;
  identity.adminRole = undefined;
  identity.authLookup = false;
  identity.usernameLookup = false;
}

export function setAdminDatabaseIdentity(staffId: string, role: string): void {
  const identity = databaseRequestIdentityStorage.getStore();
  if (!identity) return;
  identity.adminStaffId = staffId;
  identity.adminRole = role;
  identity.accountId = undefined;
  identity.sessionId = undefined;
  identity.authLookup = false;
  identity.usernameLookup = false;
}

export function setUsernameLookupDatabaseIdentity(): void {
  const identity = databaseRequestIdentityStorage.getStore();
  if (identity) identity.usernameLookup = true;
}
