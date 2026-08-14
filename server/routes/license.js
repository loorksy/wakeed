import { dbApi, generateLicenseKey } from "../db/index.js";
import {
  createSession,
  refreshSession,
  deleteSessionsForLicense,
  getLicenseByKey,
} from "../lib/session.js";
import { readJson, ok, fail } from "../lib/http.js";
import { rateLimit, clientIp } from "../lib/rate-limit.js";

export async function handleLicenseActivate(req, res) {
  if (!rateLimit("license-activate:" + clientIp(req), { windowMs: 60000, max: 15 })) {
    return fail(res, 429, "محاولات تفعيل كثيرة — انتظر قليلاً.");
  }
  const body = await readJson(req);
  const licenseKey = String(body?.licenseKey || "").trim().toUpperCase();
  const deviceId = String(body?.deviceId || "").trim();
  const deviceName = String(body?.deviceName || "").trim();
  if (!licenseKey || !deviceId) {
    return fail(res, 400, "مفتاح الترخيص ومعرّف الجهاز مطلوبان.");
  }
  const license = getLicenseByKey(licenseKey);
  if (!license) return fail(res, 404, "مفتاح الترخيص غير موجود.");
  if (license.status === "deleted") return fail(res, 403, "تم حذف الترخيص.", { code: "deleted" });
  if (license.status === "suspended") return fail(res, 403, "تم إيقاف الترخيص.", { code: "suspended" });
  if (license.device_id && license.device_id !== deviceId) {
    return fail(res, 403, "هذا الترخيص مربوط بجهاز آخر.", { code: "device_mismatch" });
  }
  const now = new Date().toISOString();
  if (!license.device_id) {
    dbApi.licenses().update((l) => l.id === license.id, {
      device_id: deviceId,
      device_name: deviceName,
      activated_at: now,
      last_seen_at: now,
      updated_at: now,
    });
    if (!dbApi.user_settings().get((u) => u.license_id === license.id)) {
      dbApi.user_settings().insert({ license_id: license.id, settings_json: "{}", theme: "dark", updated_at: now });
    }
    if (!dbApi.wakeed_credentials().get((w) => w.license_id === license.id)) {
      dbApi.wakeed_credentials().insert({ license_id: license.id, token_enc: "", owner_key: "", updated_at: now });
    }
  }
  deleteSessionsForLicense(license.id);
  const session = createSession(license.id, deviceId);
  ok(res, {
    sessionToken: session.token,
    expiresAt: session.expiresAt,
    licenseKey: license.license_key,
    label: license.label || "",
  });
}

export async function handleLicenseHeartbeat(req, res, ctx) {
  const deviceId = String(req.headers["x-device-id"] || "").trim();
  if (ctx.license.device_id && deviceId && ctx.license.device_id !== deviceId) {
    return fail(res, 403, "هذا الترخيص مربوط بجهاز آخر.", { code: "device_mismatch" });
  }
  const expiresAt = refreshSession(ctx.token);
  ok(res, { valid: true, expiresAt, status: "active" });
}

export async function handleLicenseStatus(req, res, ctx) {
  ok(res, {
    valid: true,
    licenseKey: ctx.license.license_key,
    label: ctx.license.label || "",
    status: ctx.license.status,
    deviceId: ctx.license.device_id,
    lastSeenAt: ctx.license.last_seen_at,
  });
}

export function createLicense(label = "") {
  let key = generateLicenseKey();
  for (let i = 0; i < 8; i++) {
    if (!dbApi.licenses().get((l) => l.license_key === key)) {
      const now = new Date().toISOString();
      const id = dbApi.licenses().insert({
        license_key: key,
        label: String(label || "").trim(),
        status: "active",
        created_at: now,
        updated_at: now,
      }).lastInsertRowid;
      return dbApi.licenses().get((l) => l.id === id);
    }
    key = generateLicenseKey();
  }
  throw new Error("تعذر إنشاء مفتاح ترخيص.");
}

export function listLicenses() {
  return dbApi
    .licenses()
    .all((l) => l.status !== "deleted")
    .sort((a, b) => b.id - a.id);
}

export function setLicenseStatus(id, status) {
  const now = new Date().toISOString();
  dbApi.licenses().update((l) => l.id === id, { status, updated_at: now });
  if (status === "deleted" || status === "suspended") deleteSessionsForLicense(id);
  return dbApi.licenses().get((l) => l.id === id);
}
