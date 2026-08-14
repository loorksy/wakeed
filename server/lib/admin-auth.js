import { hashAdminPassword, verifyAdminPassword, hashAdminToken } from "./crypto.js";
import { dbApi } from "../db/index.js";

const adminTokens = new Map();

export function seedAdmin() {
  const email = String(process.env.ADMIN_EMAIL || "").trim().toLowerCase();
  const password = String(process.env.ADMIN_PASSWORD || "");
  if (!email || !password) {
    console.warn("ADMIN_EMAIL / ADMIN_PASSWORD not set — admin login disabled until configured.");
    return;
  }
  const existing = dbApi.admins().get((a) => a.email === email);
  if (existing) return;
  dbApi.admins().insert({
    email,
    password_hash: hashAdminPassword(password),
    created_at: new Date().toISOString(),
  });
  console.log(`Admin seeded: ${email}`);
}

export function adminLogin(email, password) {
  const row = dbApi.admins().get((a) => a.email === String(email || "").trim().toLowerCase());
  if (!row || !verifyAdminPassword(password, row.password_hash)) return null;
  const token = hashAdminToken();
  adminTokens.set(token, { adminId: row.id, email: row.email, expiresAt: Date.now() + 12 * 3600 * 1000 });
  return { token, email: row.email };
}

export function getAdminSession(token) {
  const session = adminTokens.get(String(token || ""));
  if (!session) return null;
  if (session.expiresAt < Date.now()) {
    adminTokens.delete(token);
    return null;
  }
  return session;
}

export function adminLogout(token) {
  adminTokens.delete(String(token || ""));
}
