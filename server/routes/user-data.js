import { dbApi } from "../db/index.js";
import { encryptText, decryptText } from "../lib/crypto.js";
import { readJson, ok, fail } from "../lib/http.js";

const CRED_SECRET = () => process.env.CREDENTIALS_SECRET || process.env.SESSION_SECRET || "dev";

export function getSettings(licenseId) {
  const row = dbApi.user_settings().get((u) => u.license_id === licenseId);
  if (!row) return { settings: {}, theme: "dark" };
  let settings = {};
  try {
    settings = JSON.parse(row.settings_json || "{}");
  } catch (_) {}
  return { settings, theme: row.theme || "dark" };
}

export function saveSettings(licenseId, settings, theme) {
  const now = new Date().toISOString();
  const existing = dbApi.user_settings().get((u) => u.license_id === licenseId);
  if (existing) {
    dbApi.user_settings().update((u) => u.license_id === licenseId, {
      settings_json: JSON.stringify(settings || {}),
      theme: theme || "dark",
      updated_at: now,
    });
  } else {
    dbApi.user_settings().insert({
      license_id: licenseId,
      settings_json: JSON.stringify(settings || {}),
      theme: theme || "dark",
      updated_at: now,
    });
  }
}

export function getWakeedCredentials(licenseId) {
  const row = dbApi.wakeed_credentials().get((w) => w.license_id === licenseId);
  if (!row) return null;
  let subscriptions = [];
  try {
    subscriptions = JSON.parse(row.subscriptions_json || "[]");
  } catch (_) {}
  return {
    token: decryptText(row.token_enc, CRED_SECRET()),
    ownerKey: row.owner_key || "",
    username: row.username || "",
    server: row.server || "server1.wakeed.app",
    buildNumber: row.build_number || "3996",
    userDisplayName: row.user_display_name || "",
    subscriptions,
  };
}

export function saveWakeedCredentials(licenseId, creds) {
  const now = new Date().toISOString();
  const payload = {
    license_id: licenseId,
    token_enc: encryptText(creds.token || "", CRED_SECRET()),
    owner_key: creds.ownerKey || "",
    username: creds.username || "",
    server: creds.server || "server1.wakeed.app",
    build_number: creds.buildNumber || "3996",
    user_display_name: creds.userDisplayName || "",
    subscriptions_json: JSON.stringify(creds.subscriptions || []),
    updated_at: now,
  };
  const existing = dbApi.wakeed_credentials().get((w) => w.license_id === licenseId);
  if (existing) {
    dbApi.wakeed_credentials().update((w) => w.license_id === licenseId, payload);
  } else {
    dbApi.wakeed_credentials().insert(payload);
  }
}

export async function handleGetUserData(req, res, ctx) {
  const settingsRow = getSettings(ctx.license.id);
  const creds = getWakeedCredentials(ctx.license.id);
  ok(res, {
    settings: settingsRow.settings,
    theme: settingsRow.theme,
    wakeed: creds
      ? {
          ownerKey: creds.ownerKey,
          username: creds.username,
          server: creds.server,
          buildNumber: creds.buildNumber,
          userDisplayName: creds.userDisplayName,
          subscriptions: creds.subscriptions,
          hasToken: Boolean(creds.token),
        }
      : null,
  });
}

export async function handlePutUserData(req, res, ctx) {
  const body = await readJson(req);
  if (!body) return fail(res, 400, "JSON غير صالح.");
  if (body.settings !== undefined || body.theme !== undefined) {
    const current = getSettings(ctx.license.id);
    saveSettings(
      ctx.license.id,
      body.settings !== undefined ? body.settings : current.settings,
      body.theme !== undefined ? body.theme : current.theme
    );
  }
  if (body.wakeed && typeof body.wakeed === "object") {
    const prev = getWakeedCredentials(ctx.license.id) || {};
    saveWakeedCredentials(ctx.license.id, {
      token: body.wakeed.token !== undefined ? body.wakeed.token : prev.token,
      ownerKey: body.wakeed.ownerKey !== undefined ? body.wakeed.ownerKey : prev.ownerKey,
      username: body.wakeed.username !== undefined ? body.wakeed.username : prev.username,
      server: body.wakeed.server !== undefined ? body.wakeed.server : prev.server,
      buildNumber: body.wakeed.buildNumber !== undefined ? body.wakeed.buildNumber : prev.buildNumber,
      userDisplayName:
        body.wakeed.userDisplayName !== undefined ? body.wakeed.userDisplayName : prev.userDisplayName,
      subscriptions:
        body.wakeed.subscriptions !== undefined ? body.wakeed.subscriptions : prev.subscriptions,
    });
  }
  ok(res, { saved: true });
}

export function getWakeedCredsForProxy(licenseId) {
  return getWakeedCredentials(licenseId);
}
