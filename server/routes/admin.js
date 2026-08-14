import { readJson, ok, fail, getAdminToken } from "../lib/http.js";
import { rateLimit, clientIp } from "../lib/rate-limit.js";
import { adminLogin, adminLogout, getAdminSession } from "../lib/admin-auth.js";
import { createLicense, listLicenses, setLicenseStatus } from "./license.js";

function requireAdmin(req, res) {
  const token = getAdminToken(req);
  const session = getAdminSession(token);
  if (!session) {
    fail(res, 401, "يجب تسجيل الدخول كأدمن.");
    return null;
  }
  return { token, session };
}

export async function handleAdminLogin(req, res) {
  if (!rateLimit("admin-login:" + clientIp(req), { windowMs: 60000, max: 10 })) {
    return fail(res, 429, "محاولات كثيرة — انتظر قليلاً.");
  }
  const body = await readJson(req);
  const email = String(body?.email || "").trim();
  const password = String(body?.password || "");
  if (!email || !password) return fail(res, 400, "أدخل البريد وكلمة المرور.");
  const session = adminLogin(email, password);
  if (!session) return fail(res, 401, "بيانات الدخول غير صحيحة.");
  ok(res, session);
}

export async function handleAdminLogout(req, res) {
  adminLogout(getAdminToken(req));
  ok(res, { loggedOut: true });
}

export async function handleAdminListLicenses(req, res) {
  if (!requireAdmin(req, res)) return;
  ok(res, { licenses: listLicenses() });
}

export async function handleAdminCreateLicense(req, res) {
  if (!requireAdmin(req, res)) return;
  const body = await readJson(req);
  const license = createLicense(body?.label || "");
  ok(res, { license });
}

export async function handleAdminUpdateLicense(req, res, id, action) {
  if (!requireAdmin(req, res)) return;
  const licenseId = Number(id);
  if (!licenseId) return fail(res, 400, "معرّف غير صالح.");
  let status;
  if (action === "suspend") status = "suspended";
  else if (action === "activate") status = "active";
  else if (action === "delete") status = "deleted";
  else return fail(res, 400, "إجراء غير معروف.");
  const license = setLicenseStatus(licenseId, status);
  if (!license) return fail(res, 404, "الترخيص غير موجود.");
  ok(res, { license });
}

export async function handleAdminMe(req, res) {
  const session = requireAdmin(req, res);
  if (!session) return;
  ok(res, { email: session.session.email });
}
