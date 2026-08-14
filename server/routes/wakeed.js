import { proxyWakeed, loginWakeed } from "../wakeed-proxy.js";
import { readJson, ok, fail } from "../lib/http.js";
import { getWakeedCredsForProxy, saveWakeedCredentials, getWakeedCredentials } from "./user-data.js";

export async function handleWakeedLogin(req, res, ctx) {
  const body = await readJson(req);
  if (!body?.username || !body?.password) {
    return fail(res, 400, "أدخل المستخدم وكلمة المرور.");
  }
  const result = await loginWakeed({
    server: body.server || "server1.wakeed.app",
    username: body.username,
    password: body.password,
    buildNumber: body.buildNumber || "3996",
    deviceName: body.deviceName || "WakeedMobile",
  });
  const success = result.status >= 200 && result.status < 300;
  if (!success) {
    const msg =
      result.data?.message ||
      result.data?.Message ||
      (typeof result.data === "string" ? result.data : "فشل تسجيل الدخول.");
    return fail(res, result.status || 400, msg);
  }
  const data = result.data || {};
  saveWakeedCredentials(ctx.license.id, {
    token: data.token || "",
    ownerKey: data.ownerKey || body.ownerKey || "",
    username: body.username,
    server: body.server || "server1.wakeed.app",
    buildNumber: body.buildNumber || "3996",
    userDisplayName: data.userDisplayName || "",
    subscriptions: data.subscriptions || [],
  });
  ok(res, {
    userDisplayName: data.userDisplayName || "",
    subscriptions: data.subscriptions || [],
    ownerKey: data.ownerKey || "",
  });
}

export async function handleWakeedProxy(req, res, ctx) {
  const body = await readJson(req);
  if (!body?.path) return fail(res, 400, "مسار API مطلوب.");
  const creds = getWakeedCredsForProxy(ctx.license.id);
  if (!creds?.token) return fail(res, 401, "سجّل الدخول إلى وكيد أولاً.");
  const ownerKey = body.ownerKey || creds.ownerKey;
  const payload = {
    server: body.server || creds.server || "server1.wakeed.app",
    method: body.method || "GET",
    path: body.path,
    query: body.query || {},
    token: creds.token,
    ownerKey,
    buildNumber: body.buildNumber || creds.buildNumber || "3996",
    body: body.body,
    asForm: Boolean(body.asForm),
    contentType: body.contentType,
  };
  const result = await proxyWakeed(payload);
  const success = result.status >= 200 && result.status < 300;
  if (!success) {
    return ok(res, { ok: false, status: result.status, data: result.data });
  }
  ok(res, { ok: true, status: result.status, data: result.data });
}

export async function handleWakeedLogout(req, res, ctx) {
  const prev = getWakeedCredentials(ctx.license.id) || {};
  saveWakeedCredentials(ctx.license.id, { ...prev, token: "" });
  ok(res, { loggedOut: true });
}
