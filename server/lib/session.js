import { dbApi, generateSessionToken } from "../db/index.js";

const SESSION_TTL_HOURS = Number(process.env.SESSION_TTL_HOURS || 24);

export function sessionExpiresAt() {
  return new Date(Date.now() + SESSION_TTL_HOURS * 3600 * 1000).toISOString();
}

export function createSession(licenseId, deviceId) {
  const token = generateSessionToken();
  const expiresAt = sessionExpiresAt();
  dbApi.sessions().insert({
    license_id: licenseId,
    session_token: token,
    device_id: deviceId,
    expires_at: expiresAt,
    created_at: new Date().toISOString(),
  });
  return { token, expiresAt };
}

export function refreshSession(token) {
  const expiresAt = sessionExpiresAt();
  dbApi.sessions().update((s) => s.session_token === token, { expires_at: expiresAt });
  return expiresAt;
}

export function deleteSessionsForLicense(licenseId) {
  dbApi.sessions().delete((s) => s.license_id === licenseId);
}

export function getLicenseBySession(token) {
  const session = dbApi.sessions().get((s) => s.session_token === token);
  if (!session) return null;
  const license = dbApi.licenses().get((l) => l.id === session.license_id);
  if (!license) return null;
  const row = { ...license, session_token: session.session_token, session_device_id: session.device_id, expires_at: session.expires_at };
  if (license.status !== "active") return { ...row, invalidReason: license.status };
  if (new Date(row.expires_at).getTime() < Date.now()) return { ...row, invalidReason: "expired" };
  return row;
}

export function touchLicenseSeen(licenseId) {
  const now = new Date().toISOString();
  dbApi.licenses().update((l) => l.id === licenseId, { last_seen_at: now, updated_at: now });
}

export function getLicenseByKey(licenseKey) {
  return dbApi.licenses().get((l) => l.license_key === licenseKey);
}
